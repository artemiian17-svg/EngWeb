#include "lingoflux/store.hpp"

#include "lingoflux/json.hpp"

#include <chrono>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <utility>

namespace lingoflux {

LessonStore::LessonStore(std::string file_path) : file_path_(std::move(file_path)) {}

std::vector<Lesson> LessonStore::list() const {
    std::lock_guard lock(mutex_);
    return lessons_;
}

Lesson LessonStore::create(Lesson lesson) {
    std::lock_guard lock(mutex_);
    if (lesson.id.empty()) {
        lesson.id = make_id();
    }
    lessons_.push_back(lesson);
    return lesson;
}

bool LessonStore::remove(const std::string& id) {
    std::lock_guard lock(mutex_);
    const auto before = lessons_.size();
    std::erase_if(lessons_, [&](const Lesson& lesson) { return lesson.id == id; });
    return lessons_.size() != before;
}

void LessonStore::load() {
    std::lock_guard lock(mutex_);
    lessons_.clear();
    std::ifstream input(file_path_);
    if (!input) {
        return;
    }
    std::stringstream buffer;
    buffer << input.rdbuf();
    const auto body = buffer.str();

    std::size_t pos = 0;
    while ((pos = body.find('{', pos)) != std::string::npos) {
        const auto end = body.find('}', pos);
        if (end == std::string::npos) break;
        if (auto lesson = lesson_from_json(body.substr(pos, end - pos + 1))) {
            lessons_.push_back(*lesson);
        }
        pos = end + 1;
    }
}

void LessonStore::save() const {
    std::lock_guard lock(mutex_);
    const auto parent = std::filesystem::path(file_path_).parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent);
    }

    std::vector<std::string> items;
    for (const auto& lesson : lessons_) {
        items.push_back(to_json(lesson));
    }

    std::ofstream output(file_path_, std::ios::trunc);
    output << json::array(items);
}

std::string LessonStore::make_id() {
    const auto now = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    return "lesson-" + std::to_string(now);
}

std::string to_json(const Lesson& lesson) {
    return json::object({
        {"duration", lesson.duration},
        {"goal", lesson.goal},
        {"id", lesson.id},
        {"language", lesson.language},
        {"level", lesson.level},
        {"title", lesson.title},
    });
}

std::optional<Lesson> lesson_from_json(const std::string& body) {
    const auto object = json::parse_flat_object(body);
    if (!object) {
        return std::nullopt;
    }

    Lesson lesson;
    lesson.id = json::get_or_empty(*object, "id");
    lesson.language = json::get_or_empty(*object, "language");
    lesson.level = json::get_or_empty(*object, "level");
    lesson.title = json::get_or_empty(*object, "title");
    lesson.duration = json::get_or_empty(*object, "duration");
    lesson.goal = json::get_or_empty(*object, "goal");
    return lesson;
}

} // namespace lingoflux
