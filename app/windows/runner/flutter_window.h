#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that hosts a Flutter view, adds a tray icon and can switch between the
// normal window and a compact borderless popup near the tray (menu-bar style).
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void SetupChannel();
  void AddTrayIcon();
  void RemoveTrayIcon();
  void ShowTrayMenu();
  void SetCompact(bool compact);
  void ToggleCompact();
  void NotifyMode();
  void Quit();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Channel "moondrop/window" (Dart <-> native).
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  bool compact_ = false;
  bool close_to_tray_ = false;
  bool quitting_ = false;
  bool tray_added_ = false;
  ULONGLONG last_hide_tick_ = 0;
  RECT full_rect_ = {0, 0, 0, 0};
  UINT taskbar_created_msg_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
