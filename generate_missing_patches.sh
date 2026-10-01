#!/bin/bash
set -e

# 7. ErrorUtils.cpp
cat << 'PATCH7' > patches/0007-macos-errorutils.patch
--- source/main/utils/ErrorUtils.cpp
+++ source/main/utils/ErrorUtils.cpp
@@ -34,6 +34,7 @@
 #include <shellapi.h> // for ShellExecuteW
 #define _L
 #elif OGRE_PLATFORM == OGRE_PLATFORM_APPLE
+#include "MacOS.h"
 #define _L
 #elif OGRE_PLATFORM == OGRE_PLATFORM_LINUX
 #include "Language.h"
@@ -69,9 +70,7 @@
 #elif OGRE_PLATFORM == OGRE_PLATFORM_LINUX
 	printf("\n\n%s: %s\n\n", title.c_str(), err.c_str());
 #elif OGRE_PLATFORM == OGRE_PLATFORM_APPLE
-	printf("\n\n%s: %s\n\n", title.c_str(), err.c_str());
-    //CFOptionFlags flgs;
-    //CFUserNotificationDisplayAlert(0, kCFUserNotificationStopAlertLevel, NULL, NULL, NULL, T("A network error occured"), T("Bad server port."), NULL, NULL, NULL, &flgs);
+    RoR::MacOS::ShowAlert(title, err, type == 1);
 #endif
     return 0;
 }
PATCH7

# 8. main.cpp
cat << 'PATCH8' > patches/0008-macos-main-pump.patch
--- source/main/main.cpp
+++ source/main/main.cpp
@@ -48,6 +48,9 @@
 #include "SoundScriptManager.h"
 #include "Terrain.h"
 #include "Utils.h"
+#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE
+#include "MacOS.h"
+#endif
 #include <Overlay/OgreOverlaySystem.h>
 #include <ctime>
 #include <iomanip>
@@ -332,7 +335,15 @@
         while (App::app_state->getEnum<AppState>() != AppState::SHUTDOWN)
         {
             App::GetAppContext()->PrepareProfiler();
+#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE
+            RoR::MacOS::PumpEvents();
+            if (RoR::MacOS::ConsumeQuitRequest())
+            {
+                App::GetGameContext()->PushMessage(Message(MSG_APP_SHUTDOWN_REQUESTED));
+            }
+#else
             OgreBites::WindowEventUtilities::messagePump();
+#endif
 
             // Halt physics (wait for async tasks to finish)
             if (App::app_state->getEnum<AppState>() == AppState::SIMULATION)
PATCH8

# 9. AppContext.cpp window setup
cat << 'PATCH9' > patches/0009-macos-appcontext-window.patch
--- source/main/AppContext.cpp
+++ source/main/AppContext.cpp
@@ -373,12 +373,22 @@
     }
     LOG(fmt::format("[RoR|Startup|Rendering] Creating render window with settings:\n{}", miscParams_log.str()));
 
+#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE
+    RoR::MacOS::InitApplication();
+#endif
+
     // Create render window
     m_render_window = Ogre::Root::getSingleton().createRenderWindow (
         "Rigs of Rods version " + Ogre::String (ROR_VERSION_STRING),
         width, height, ropts["Full Screen"].currentValue == "Yes", &miscParams);
+
+#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE
+    size_t ns_window = 0;
+    m_render_window->getCustomAttribute("WINDOW", &ns_window);
+    RoR::MacOS::AttachToWindow((void*)ns_window);
+#else
     OgreBites::WindowEventUtilities::_addRenderWindow(m_render_window);
     OgreBites::WindowEventUtilities::addWindowEventListener(m_render_window, this);
+#endif
 
     // Init debug drawing
PATCH9

