/*
 * pikafish_bridge implementation. Same rdbuf-swap technique as
 * rapfi_bridge.cpp — see that file for the rationale. This one drives
 * Pikafish's UCIEngine::loop() (src/uci.cpp), which reads whole lines via
 * std::getline(std::cin, ...) and writes through the sync_cout/std::cout
 * machinery in src/misc.h.
 */
#include "pikafish_bridge.h"

#include "attacks.h"
#include "misc.h"
#include "position.h"
#include "tune.h"
#include "uci.h"

#include <condition_variable>
#include <cstring>
#include <deque>
#include <iostream>
#include <memory>
#include <mutex>
#include <streambuf>
#include <string>
#include <thread>

namespace {

class InputQueueBuf : public std::streambuf {
public:
    void push(const std::string &s)
    {
        {
            std::lock_guard<std::mutex> lk(mutex_);
            queue_.insert(queue_.end(), s.begin(), s.end());
        }
        cv_.notify_all();
    }

protected:
    int_type underflow() override
    {
        std::unique_lock<std::mutex> lk(mutex_);
        cv_.wait(lk, [this] { return !queue_.empty(); });
        current_ = queue_.front();
        queue_.pop_front();
        setg(&current_, &current_, &current_ + 1);
        return traits_type::to_int_type(current_);
    }

private:
    std::mutex              mutex_;
    std::condition_variable cv_;
    std::deque<char>        queue_;
    char                    current_ = 0;
};

class LineQueueBuf : public std::streambuf {
public:
    bool popLine(std::string &out, int timeout_ms)
    {
        std::unique_lock<std::mutex> lk(mutex_);
        bool ok = cv_.wait_for(lk, std::chrono::milliseconds(timeout_ms), [this] {
            return !lines_.empty();
        });
        if (!ok)
            return false;
        out = std::move(lines_.front());
        lines_.pop_front();
        return true;
    }

protected:
    int_type overflow(int_type c) override
    {
        if (c == traits_type::eof())
            return c;
        char ch = traits_type::to_char_type(c);
        std::lock_guard<std::mutex> lk(mutex_);
        if (ch == '\n') {
            lines_.push_back(std::move(partial_));
            partial_.clear();
            cv_.notify_all();
        }
        else {
            partial_.push_back(ch);
        }
        return c;
    }

private:
    std::mutex              mutex_;
    std::condition_variable cv_;
    std::string             partial_;
    std::deque<std::string> lines_;
};

InputQueueBuf engineInput;
LineQueueBuf  engineOutput;
std::thread   engineThread;
bool          started = false;

}  // namespace

extern "C" int pikafish_start(void)
{
    if (started)
        return 1;
    started = true;

    std::cin.rdbuf(&engineInput);
    std::cout.rdbuf(&engineOutput);

    engineThread = std::thread([] {
        using namespace Stockfish;

        Attacks::init();
        Position::init();

        static char  arg0[] = "pikafish";
        static char *argv[] = {arg0, nullptr};
        auto         cli    = CommandLine(1, argv);
        auto         uci    = std::make_unique<UCIEngine>(std::move(cli));

        Tune::init(uci->engine_options());

        uci->loop();
    });
    engineThread.detach();
    return 0;
}

extern "C" void pikafish_send(const char *line)
{
    std::string s(line);
    s.push_back('\n');
    engineInput.push(s);
}

extern "C" int pikafish_recv(char *buf, int buf_capacity, int timeout_ms)
{
    std::string line;
    if (!engineOutput.popLine(line, timeout_ms))
        return -1;
    if ((int)line.size() + 1 > buf_capacity)
        return -2;
    std::memcpy(buf, line.c_str(), line.size() + 1);
    return (int)line.size();
}
