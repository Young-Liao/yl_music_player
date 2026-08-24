#pragma once

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// 声明全局 MethodChannel 变量（供 main.cpp 访问）
extern std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_method_channel;

class FlutterWindow : public Win32Window {
public:
    explicit FlutterWindow(const flutter::DartProject& project);
    virtual ~FlutterWindow();

protected:
    bool OnCreate() override;
    void OnDestroy() override;
    LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                           LPARAM const lparam) noexcept override;

private:
    flutter::DartProject project_;
    std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};