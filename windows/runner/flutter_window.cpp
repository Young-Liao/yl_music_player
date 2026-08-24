#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// 定义全局变量
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_method_channel = nullptr;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
        : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
          frame.right - frame.left, frame.bottom - frame.top, project_);

  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // === 在这里初始化全局 MethodChannel ===
  auto messenger = flutter_controller_->engine()->messenger();
  g_method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.youngl.ylmusic/args",
                  &flutter::StandardMethodCodec::GetInstance());

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
      this->Show();
  });

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
if (flutter_controller_) {
std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
if (result) {
return *result;
}
}

return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}