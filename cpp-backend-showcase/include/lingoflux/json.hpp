#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

namespace lingoflux::json {

using Object = std::map<std::string, std::string>;

std::string escape(const std::string& value);
std::string object(const Object& values);
std::string raw_object(const std::map<std::string, std::string>& values);
std::string array(const std::vector<std::string>& items);
std::optional<Object> parse_flat_object(const std::string& source);
std::string get_or_empty(const Object& object, const std::string& key);

} // namespace lingoflux::json
