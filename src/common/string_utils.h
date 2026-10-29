#pragma once

#include <string>

namespace codex_proxy {

std::wstring Utf8ToWide(const std::string& value);
std::wstring ToLower(std::wstring value);
std::string ToLower(std::string value);
std::string Trim(std::string value);

}  // namespace codex_proxy
