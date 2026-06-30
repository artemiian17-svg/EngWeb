#pragma once

#include <mutex>
#include <optional>
#include <string>
#include <vector>

namespace lingoflux {

struct Lesson {
    std::string id;
    std::string language;
    std::string level;
    std::string title;
    std::string duration;
    std::string goal;
};

class LessonStore {
public:
    explicit LessonStore(std::string file_path = "data/lessons.json");

    std::vector<Lesson> list() const;
    Lesson create(Lesson lesson);
    bool remove(const std::string& id);
    void load();
    void save() const;

private:
    static std::string make_id();

    std::string file_path_;
    mutable std::mutex mutex_;
    std::vector<Lesson> lessons_;
};

std::string to_json(const Lesson& lesson);
std::optional<Lesson> lesson_from_json(const std::string& body);

} // namespace lingoflux
