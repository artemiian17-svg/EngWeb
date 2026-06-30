#include "lingoflux/json.hpp"

#include <cctype>
#include <sstream>

namespace lingoflux::json {
namespace {

void skip_ws(const std::string& source, std::size_t& pos) {
    while (pos < source.size() && std::isspace(static_cast<unsigned char>(source[pos]))) {
        ++pos;
    }
}

std::optional<std::string> parse_string(const std::string& source, std::size_t& pos) {
    skip_ws(source, pos);
    if (pos >= source.size() || source[pos] != '"') {
        return std::nullopt;
    }
    ++pos;
    std::string result;
    while (pos < source.size()) {
        const char ch = source[pos++];
        if (ch == '"') {
            return result;
        }
        if (ch == '\\' && pos < source.size()) {
            const char escaped = source[pos++];
            if (escaped == '"' || escaped == '\\' || escaped == '/') result.push_back(escaped);
            else if (escaped == 'n') result.push_back('\n');
            else if (escaped == 'r') result.push_back('\r');
            else if (escaped == 't') result.push_back('\t');
            else return std::nullopt;
        } else {
            result.push_back(ch);
        }
    }
    return std::nullopt;
}

} // namespace

std::string escape(const std::string& value) {
    std::ostringstream out;
    for (const char ch : value) {
        switch (ch) {
            case '"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\n': out << "\\n"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            default: out << ch; break;
        }
    }
    return out.str();
}

std::string object(const Object& values) {
    std::ostringstream out;
    out << '{';
    bool first = true;
    for (const auto& [key, value] : values) {
        if (!first) out << ',';
        first = false;
        out << '"' << escape(key) << "\":\"" << escape(value) << '"';
    }
    out << '}';
    return out.str();
}

std::string raw_object(const std::map<std::string, std::string>& values) {
    std::ostringstream out;
    out << '{';
    bool first = true;
    for (const auto& [key, value] : values) {
        if (!first) out << ',';
        first = false;
        out << '"' << escape(key) << "\":" << value;
    }
    out << '}';
    return out.str();
}

std::string array(const std::vector<std::string>& items) {
    std::ostringstream out;
    out << '[';
    for (std::size_t i = 0; i < items.size(); ++i) {
        if (i != 0) out << ',';
        out << items[i];
    }
    out << ']';
    return out.str();
}

std::optional<Object> parse_flat_object(const std::string& source) {
    std::size_t pos = 0;
    skip_ws(source, pos);
    if (pos >= source.size() || source[pos++] != '{') {
        return std::nullopt;
    }

    Object result;
    skip_ws(source, pos);
    while (pos < source.size() && source[pos] != '}') {
        auto key = parse_string(source, pos);
        if (!key) return std::nullopt;
        skip_ws(source, pos);
        if (pos >= source.size() || source[pos++] != ':') return std::nullopt;
        auto value = parse_string(source, pos);
        if (!value) return std::nullopt;
        result[*key] = *value;
        skip_ws(source, pos);
        if (pos < source.size() && source[pos] == ',') {
            ++pos;
            skip_ws(source, pos);
        }
    }

    if (pos >= source.size() || source[pos] != '}') {
        return std::nullopt;
    }
    return result;
}

std::string get_or_empty(const Object& object, const std::string& key) {
    const auto it = object.find(key);
    return it == object.end() ? "" : it->second;
}

} // namespace lingoflux::json
