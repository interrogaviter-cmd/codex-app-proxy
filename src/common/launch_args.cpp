#include "common/launch_args.h"

#include "common/string_utils.h"

#include <windows.h>

namespace codex_proxy {
namespace {

std::wstring JoinBypassList(const std::vector<std::string>& values) {
  std::wstring result;
  for (const auto& value : values) {
    if (!result.empty()) {
      result += L";";
    }
    result += Utf8ToWide(value);
  }
  return result;
}

}  // namespace

std::wstring ProxyUrl(const AppConfig& config) {
  return Utf8ToWide(ProxyTypeToString(config.proxy.type)) + L"://" +
         Utf8ToWide(config.proxy.host) + L":" +
         std::to_wstring(config.proxy.port);
}

bool SetProxyEnvironmentForChild(const AppConfig& config, std::wstring* error) {
  const std::wstring proxy = ProxyUrl(config);
  for (const wchar_t* name : {L"HTTP_PROXY", L"HTTPS_PROXY", L"ALL_PROXY"}) {
    if (!SetEnvironmentVariableW(name, proxy.c_str())) {
      if (error) {
        *error = std::wstring(L"无法设置进程代理变量 ") + name +
                 L" (Windows " + std::to_wstring(GetLastError()) + L")";
      }
      return false;
    }
  }
  return true;
}

std::wstring BuildAppArguments(const AppConfig& config) {
  std::wstring command = L"--proxy-server=\"" + ProxyUrl(config) + L"\"";

  const std::wstring bypass = JoinBypassList(config.bypass_list);
  if (!bypass.empty()) {
    command += L" --proxy-bypass-list=\"" + bypass + L"\"";
  }
  if (config.disable_quic) {
    command += L" --disable-quic";
  }
  return command;
}

std::wstring BuildAppCommandLine(const std::wstring& app_path,
                                 const AppConfig& config) {
  return L"\"" + app_path + L"\" " + BuildAppArguments(config);
}

}  // namespace codex_proxy
