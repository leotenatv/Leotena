#include "flutter_window.h"

#include <optional>
#include <variant>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.ghettodevelopers.leotena/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setFullScreen") {
          bool enable = false;
          if (call.arguments() != nullptr) {
            const bool* flag = std::get_if<bool>(call.arguments());
            if (flag != nullptr) {
              enable = *flag;
            }
          }
          SetFullScreen(enable);
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  integrity_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.ghettodevelopers.leotena/integrity",
          &flutter::StandardMethodCodec::GetInstance());
  integrity_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "inspect") {
          // A Windows proxy or phone hotspot is a normal connection. Do not
          // treat it as a block; playback connects directly.
          flutter::EncodableMap report;
          report[flutter::EncodableValue("blocked")] =
              flutter::EncodableValue(false);
          result->Success(flutter::EncodableValue(report));
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetFullScreen(bool enabled) {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr || enabled == fullscreen_) {
    return;
  }

  if (enabled) {
    saved_style_ = GetWindowLong(hwnd, GWL_STYLE);
    saved_placement_.length = sizeof(WINDOWPLACEMENT);
    GetWindowPlacement(hwnd, &saved_placement_);

    HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info;
    info.cbSize = sizeof(MONITORINFO);
    if (!GetMonitorInfo(monitor, &info)) {
      return;
    }

    SetWindowLong(hwnd, GWL_STYLE,
                  saved_style_ & ~(WS_CAPTION | WS_THICKFRAME | WS_MAXIMIZEBOX |
                                   WS_MINIMIZEBOX | WS_SYSMENU | WS_BORDER));
    SetWindowPos(hwnd, HWND_TOP, info.rcMonitor.left, info.rcMonitor.top,
                 info.rcMonitor.right - info.rcMonitor.left,
                 info.rcMonitor.bottom - info.rcMonitor.top,
                 SWP_FRAMECHANGED | SWP_NOOWNERZORDER);
    fullscreen_ = true;
    return;
  }

  SetWindowLong(hwnd, GWL_STYLE, saved_style_);
  SetWindowPlacement(hwnd, &saved_placement_);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER |
                   SWP_FRAMECHANGED);
  fullscreen_ = false;
}

void FlutterWindow::OnDestroy() {
  if (integrity_channel_) {
    integrity_channel_->SetMethodCallHandler(nullptr);
    integrity_channel_ = nullptr;
  }
  if (window_channel_) {
    window_channel_->SetMethodCallHandler(nullptr);
    window_channel_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_GETMINMAXINFO: {
      Win32Window::MessageHandler(hwnd, message, wparam, lparam);
      const UINT dpi = GetDpiForWindow(hwnd);
      const double scale = dpi > 0 ? dpi / 96.0 : 1.0;
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = static_cast<LONG>(960 * scale);
      info->ptMinTrackSize.y = static_cast<LONG>(640 * scale);
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
