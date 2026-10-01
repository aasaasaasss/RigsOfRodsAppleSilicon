#!/bin/bash
set -e

# 1. PlatformUtils
cat << 'PATCH1' > patches/0001-macos-platformutils.patch
--- source/main/utils/PlatformUtils.cpp
+++ source/main/utils/PlatformUtils.cpp
@@ -35,6 +35,9 @@
     #include <sys/types.h>
     #include <sys/stat.h>
     #include <unistd.h> // readlink()
+    #ifdef __APPLE__
+        #include <mach-o/dyld.h>
+    #endif
 #endif
 
 #include <OgrePlatform.h>
@@ -158,11 +161,21 @@
 {
     const int BUF_SIZE = 500;
     std::string buf_str(BUF_SIZE, 0);
+#ifdef __APPLE__
+    uint32_t size = BUF_SIZE;
+    if (_NSGetExecutablePath(&buf_str[0], &size) != 0)
+    {
+        RoR::Log("[RoR] Internal error: GetExecutablePath() failed; _NSGetExecutablePath buffer too small");
+        return std::string();
+    }
+    buf_str.resize(strlen(buf_str.c_str()));
+    return buf_str;
+#else
     // Linux or POSIX assumed; http://stackoverflow.com/a/625523
     if (readlink("/proc/self/exe", &buf_str[0], BUF_SIZE-1) == -1)
     {
         RoR::LogFormat("[RoR] Internal error: GetExecutablePath() failed; readlink() sets errno to %d", static_cast<int>(errno));
         return std::string();
     }
-
-    return std::move(buf_str);
+    return buf_str;
+#endif
 }
 
 void OpenUrlInDefaultBrowser(std::string const& url)
 {
+#ifdef __APPLE__
+    std::string buf = "open " + url;
+#else
     std::string buf = "xdg-open " + url;
+#endif
     ::system(buf.c_str());
 }
PATCH1

# 2. InputEngine
cat << 'PATCH2' > patches/0002-macos-inputengine.patch
--- source/main/utils/InputEngine.cpp
+++ source/main/utils/InputEngine.cpp
@@ -395,9 +395,5 @@
     {"", -1, "", ""},
 };
 
-#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE
-#define strnlen(str,len) strlen(str)
-#endif
-
 //Use this define to signify OIS will be used as a DLL
 //(so that dll import/export macros are in effect)
@@ -492,6 +488,8 @@
         pl.insert(OIS::ParamList::value_type("XAutoRepeatOn", "false"));
         pl.insert(OIS::ParamList::value_type("x11_mouse_grab", "false"));
         pl.insert(OIS::ParamList::value_type("x11_keyboard_grab", "false"));
+#elif OGRE_PLATFORM == OGRE_PLATFORM_APPLE
+        pl.insert(OIS::ParamList::value_type("MacAutoRepeatOn", "false"));
 #else
         pl.insert(OIS::ParamList::value_type("w32_mouse", "DISCL_FOREGROUND"));
         pl.insert(OIS::ParamList::value_type("w32_mouse", "DISCL_NONEXCLUSIVE"));
PATCH2

# 3. AppContext
cat << 'PATCH3' > patches/0003-macos-appcontext-resources.patch
--- source/main/AppContext.cpp
+++ source/main/AppContext.cpp
@@ -35,6 +35,10 @@
 #include <OgreResourceGroupManager.h>
 #include <OgreConfigPaths.h>
 
+#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE
+#include "MacOS.h"
+#endif
+
 using namespace RoR;
 
 AppContext::AppContext() :
@@ -560,6 +564,13 @@
         process_dir = "/usr/share/rigsofrods/resources/";
     }
 #endif
+#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE
+    std::string bundle_res = RoR::MacOS::GetBundleResourcesDir();
+    if (!bundle_res.empty())
+    {
+        process_dir = bundle_res;
+    }
+#endif
     if (!FolderExists(process_dir))
     {
         ErrorUtils::ShowError(_L("Startup error"), _L("Resources folder not found. Check if correctly installed."));
PATCH3

# 4. Sound.h and SoundManager.h
cat << 'PATCH4' > patches/0004-macos-openal-headers.patch
--- source/main/audio/Sound.h
+++ source/main/audio/Sound.h
@@ -26,10 +26,10 @@
 
 #ifdef __APPLE__
-  #include <OpenAL/al.h>
-  #include <OpenAL/alc.h>
-  #include <OpenAL/alext.h>
-  #include <OpenAL/efx-presets.h>
+  #include <AL/al.h>
+  #include <AL/alc.h>
+  #include <AL/alext.h>
+  #include <AL/efx-presets.h>
 #else
   #include <AL/al.h>
   #include <AL/alc.h>
--- source/main/audio/SoundManager.h
+++ source/main/audio/SoundManager.h
@@ -34,10 +34,10 @@
 
 #ifdef __APPLE__
-  #include <OpenAL/al.h>
-  #include <OpenAL/alc.h>
-  #include <OpenAL/alext.h>
-  #include <OpenAL/efx-presets.h>
+  #include <AL/al.h>
+  #include <AL/alc.h>
+  #include <AL/alext.h>
+  #include <AL/efx-presets.h>
 #else
   #include <AL/al.h>
   #include <AL/alc.h>
PATCH4

# 5. CMakeLists.txt
cat << 'PATCH5' > patches/0005-macos-cmake.patch
--- source/main/CMakeLists.txt
+++ source/main/CMakeLists.txt
@@ -342,6 +342,11 @@
 # Expand file extensions (i.e. path/to/file.{h,cpp} becomes path/to/file.h;path/to/file.cpp)
 expand_file_extensions(SOURCE_FILES ${SOURCE_FILES})
 
+if (APPLE)
+    list(APPEND SOURCE_FILES MacOS.h MacOS.mm)
+    set_source_files_properties(MacOS.mm PROPERTIES COMPILE_FLAGS "-fno-objc-arc")
+endif ()
+
 # Generate source groups for use in IDEs
 source_group(TREE ${CMAKE_CURRENT_LIST_DIR} FILES ${SOURCE_FILES})
 
@@ -409,6 +414,8 @@
 
 if (WIN32)
     set(OS_LIBS "Ws2_32")
+elseif (APPLE)
+    set(OS_LIBS "-framework Cocoa -framework IOKit -framework AppKit")
 else ()
     #  include_directories(${GTK_INCLUDE_DIRS})
     set(OS_LIBS "X11 -l${CMAKE_DL_LIBS} -lrt")
PATCH5

# 6. conanfile.py
cat << 'PATCH6' > patches/0006-macos-conanfile.patch
--- conanfile.py
+++ conanfile.py
@@ -16,7 +16,8 @@
 
     def requirements(self):
         self.requires("angelscript/2.38.0")
-        self.requires("discord-rpc/3.4.0@anotherfoxguy/stable")
+        if self.settings.os != "Macos":
+            self.requires("discord-rpc/3.4.0@anotherfoxguy/stable")
         self.requires("libcurl/8.2.1")
         self.requires("fmt/12.2.0")
         self.requires("mygui/3.4.0@anotherfoxguy/stable")
@@ -46,3 +47,4 @@
         bindir = os.path.join(self.build_folder, "bin")
         copy(self, "*.dll", src, bindir, False)
         copy(self, "*.so*", src, bindir, False)
+        copy(self, "*.dylib", src, bindir, False)
PATCH6

