#include "flutter_window.h"

#include <shellapi.h>

#include <algorithm>
#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kTrayId = 1;
constexpr UINT kCmdOpen = 1001;
constexpr UINT kCmdCompact = 1002;
constexpr UINT kCmdQuit = 1003;

// Tamanho do painel compacto (pixels logicos).
constexpr int kCompactWidth = 392;
constexpr int kCompactHeight = 760;
constexpr int kCompactMargin = 12;
constexpr int kCompactRadius = 26;
}  // namespace

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupChannel();
  taskbar_created_msg_ = RegisterWindowMessageW(L"TaskbarCreated");
  AddTrayIcon();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// ------------------------------------------------------------------ canal Dart
void FlutterWindow::SetupChannel() {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "moondrop/window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        bool arg = false;
        if (const auto* a = call.arguments()) {
          if (const bool* b = std::get_if<bool>(a)) arg = *b;
        }
        const std::string& m = call.method_name();
        if (m == "setCompact") {
          SetCompact(arg);
        } else if (m == "setCloseToTray") {
          close_to_tray_ = arg;
        } else if (m == "quit") {
          Quit();
        } else {
          result->NotImplemented();
          return;
        }
        result->Success();
      });
}

void FlutterWindow::NotifyMode() {
  if (!channel_) return;
  channel_->InvokeMethod(
      "mode", std::make_unique<flutter::EncodableValue>(
                  std::string(compact_ ? "compact" : "full")));
}

void FlutterWindow::Quit() {
  quitting_ = true;
  DestroyWindow(GetHandle());
}

// --------------------------------------------------------------------- bandeja
void FlutterWindow::AddTrayIcon() {
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = GetHandle();
  nid.uID = kTrayId;
  nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  nid.uCallbackMessage = kTrayMessage;
  nid.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON));
  wcscpy_s(nid.szTip, L"MOONDROP PC");
  tray_added_ = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_added_) return;
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = GetHandle();
  nid.uID = kTrayId;
  Shell_NotifyIconW(NIM_DELETE, &nid);
  tray_added_ = false;
}

void FlutterWindow::ShowTrayMenu() {
  HWND hwnd = GetHandle();
  HMENU menu = CreatePopupMenu();
  AppendMenuW(menu, MF_STRING, kCmdOpen, L"Abrir MOONDROP");
  AppendMenuW(menu, MF_STRING, kCmdCompact, L"Modo compacto");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kCmdQuit, L"Sair");
  POINT pt;
  GetCursorPos(&pt);
  SetForegroundWindow(hwnd);  // necessario para o menu fechar ao clicar fora
  TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, pt.x, pt.y, 0, hwnd,
                 nullptr);
  PostMessageW(hwnd, WM_NULL, 0, 0);
  DestroyMenu(menu);
}

// ---------------------------------------------------------------- modo compacto
void FlutterWindow::SetCompact(bool compact) {
  HWND hwnd = GetHandle();
  if (compact == compact_ && IsWindowVisible(hwnd)) {
    if (compact) SetForegroundWindow(hwnd);
    return;
  }
  const double scale = GetDpiForWindow(hwnd) / 96.0;

  if (compact) {
    if (!compact_) GetWindowRect(hwnd, &full_rect_);
    compact_ = true;

    RECT work;
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
    const int margin = static_cast<int>(kCompactMargin * scale);
    int w = static_cast<int>(kCompactWidth * scale);
    int h = static_cast<int>(kCompactHeight * scale);
    h = std::min<int>(h, (work.bottom - work.top) - 2 * margin);
    const int x = work.right - w - margin;
    const int y = work.bottom - h - margin;

    SetWindowLongPtrW(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    SetWindowLongPtrW(hwnd, GWL_EXSTYLE, WS_EX_TOOLWINDOW | WS_EX_TOPMOST);
    SetWindowPos(hwnd, HWND_TOPMOST, x, y, w, h,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    const int r = static_cast<int>(kCompactRadius * scale);
    SetWindowRgn(hwnd, CreateRoundRectRgn(0, 0, w + 1, h + 1, r, r), TRUE);
    SetForegroundWindow(hwnd);
  } else {
    compact_ = false;
    SetWindowRgn(hwnd, nullptr, TRUE);
    SetWindowLongPtrW(hwnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
    SetWindowLongPtrW(hwnd, GWL_EXSTYLE, WS_EX_APPWINDOW);
    RECT r = full_rect_;
    if (r.right - r.left < 200 || r.bottom - r.top < 200) {
      r = {100, 100, 100 + static_cast<int>(1280 * scale),
           100 + static_cast<int>(720 * scale)};
    }
    SetWindowPos(hwnd, HWND_NOTOPMOST, r.left, r.top, r.right - r.left,
                 r.bottom - r.top, SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
  }
  NotifyMode();
}

void FlutterWindow::ToggleCompact() {
  HWND hwnd = GetHandle();
  if (compact_ && IsWindowVisible(hwnd)) {
    ShowWindow(hwnd, SW_HIDE);
    return;
  }
  // Se o painel acabou de sumir por perder o foco (o proprio clique no icone),
  // nao reabre na hora.
  if (compact_ && GetTickCount64() - last_hide_tick_ < 350) return;
  SetCompact(true);
}

// ------------------------------------------------------------------- mensagens
LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kTrayMessage) {
    if (lparam == WM_LBUTTONUP) {
      ToggleCompact();
    } else if (lparam == WM_RBUTTONUP) {
      ShowTrayMenu();
    }
    return 0;
  }
  if (taskbar_created_msg_ != 0 && message == taskbar_created_msg_) {
    tray_added_ = false;
    AddTrayIcon();  // o Explorer reiniciou
    return 0;
  }
  switch (message) {
    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kCmdOpen:
          SetCompact(false);
          return 0;
        case kCmdCompact:
          SetCompact(true);
          return 0;
        case kCmdQuit:
          Quit();
          return 0;
      }
      break;
    case WM_ACTIVATE:
      // Painel compacto some ao clicar fora (como o popover da barra de menu).
      if (compact_ && LOWORD(wparam) == WA_INACTIVE) {
        ShowWindow(hwnd, SW_HIDE);
        last_hide_tick_ = GetTickCount64();
      }
      break;
    case WM_CLOSE:
      if (close_to_tray_ && !quitting_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
  }

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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
