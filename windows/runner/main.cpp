#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Same identity as the Android applicationId.
  ::SetCurrentProcessExplicitAppUserModelID(L"com.ghettodevelopers.leotena");

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  unsigned int window_width = 1360;
  unsigned int window_height = 840;
  int origin_x = 24;
  int origin_y = 24;
  POINT origin_point = {0, 0};
  HMONITOR monitor =
      ::MonitorFromPoint(origin_point, MONITOR_DEFAULTTOPRIMARY);
  UINT dpi = ::FlutterDesktopGetDpiForMonitor(monitor);
  double scale = dpi > 0 ? dpi / 96.0 : 1.0;
  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(monitor_info);
  if (::GetMonitorInfo(monitor, &monitor_info)) {
    const int work_w = monitor_info.rcWork.right - monitor_info.rcWork.left;
    const int work_h = monitor_info.rcWork.bottom - monitor_info.rcWork.top;
    if (static_cast<int>(window_width * scale) > work_w - 48) {
      window_width = static_cast<unsigned int>((work_w - 48) / scale);
    }
    if (static_cast<int>(window_height * scale) > work_h - 48) {
      window_height = static_cast<unsigned int>((work_h - 48) / scale);
    }
    origin_x = static_cast<int>(monitor_info.rcWork.left / scale) +
               static_cast<int>((work_w / scale - window_width) / 2);
    origin_y = static_cast<int>(monitor_info.rcWork.top / scale) +
               static_cast<int>((work_h / scale - window_height) / 2);
    if (origin_x < 0) origin_x = 24;
    if (origin_y < 0) origin_y = 24;
  }
  Win32Window::Point origin(static_cast<unsigned int>(origin_x),
                            static_cast<unsigned int>(origin_y));
  Win32Window::Size size(window_width, window_height);
  if (!window.Create(L"Leotena", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
