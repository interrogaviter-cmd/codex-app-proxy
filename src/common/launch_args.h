#pragma once

#include "common/config.h"

#include <string>

namespace codex_proxy {

std::wstring ProxyUrl(const AppConfig& config);
bool SetProxyEnvironmentForChild(const AppConfig& config, std::wstring* error);
std::wstring BuildAppArguments(const AppConfig& config);
std::wstring BuildAppCommandLine(const std::wstring& app_path,
                                 const AppConfig& config);

}  // namespace codex_proxy
