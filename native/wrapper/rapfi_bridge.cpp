/*
 * rapfi_bridge implementation.
 *
 * The engine's gomocupLoop() reads std::cin and writes std::cout. Instead of
 * dup2()-ing the process-wide file descriptors (which would swallow the host
 * app's own stdout, e.g. Swift print()), we swap the C++ stream buffers with
 * thread-safe in-memory pipes. C-level stdio and the host language's printing
 * are untouched.
 */
#include "rapfi_bridge.h"

#include "command/command.h"

#include <condition_variable>
#include <cstring>
#include <iostream>
#include <deque>
#include <mutex>
#include <streambuf>
#include <string>
#include <thread>

namespace {

// std::cin replacement: underflow() blocks until the host pushes input.
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

// std::cout replacement: buffers engine output and hands out whole lines.
class LineQueueBuf : public std::streambuf {
public:
    // Returns false on timeout.
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

extern "C" int rapfi_start(void)
{
    if (started)
        return 1;
    started = true;

    std::cin.rdbuf(&engineInput);
    std::cout.rdbuf(&engineOutput);

    engineThread = std::thread([] {
        static char  arg0[] = "rapfi";
        static char *argv[] = {arg0, nullptr};
        Command::CommandLine::init(1, argv);
        Command::loadConfig();
        Command::gomocupLoop();
    });
    engineThread.detach();
    return 0;
}

extern "C" void rapfi_send(const char *line)
{
    std::string s(line);
    s.push_back('\n');
    engineInput.push(s);
}

extern "C" int rapfi_recv(char *buf, int buf_capacity, int timeout_ms)
{
    std::string line;
    if (!engineOutput.popLine(line, timeout_ms))
        return -1;
    if ((int)line.size() + 1 > buf_capacity)
        return -2;
    std::memcpy(buf, line.c_str(), line.size() + 1);
    return (int)line.size();
}
