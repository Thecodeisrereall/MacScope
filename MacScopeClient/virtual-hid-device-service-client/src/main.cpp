#include <atomic>
#include <chrono>
#include <ctime>
#include <filesystem>
#include <iostream>
#include <map>
#include <mutex>
#include <string>
#include <thread>

// POSIX socket headers
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <signal.h>
#include <pwd.h>
#include <sys/stat.h>

// Karabiner VirtualHID headers
#include <pqrs/karabiner/driverkit/virtual_hid_device_driver.hpp>
#include <pqrs/karabiner/driverkit/virtual_hid_device_service.hpp>
#include <pqrs/local_datagram.hpp>

// JSON library
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace {
// Global state
std::atomic<bool> exit_flag(false);
std::atomic<bool> driver_ready(false);
std::atomic<bool> keyboard_ready(false);
std::atomic<bool> pointing_ready(false);

int socket_fd = -1;
std::string socket_path;
std::mutex hid_mutex;

std::unique_ptr<pqrs::karabiner::driverkit::virtual_hid_device_service::client> vhid_client;

// Key name to HID usage code mapping
std::map<std::string, pqrs::hid::usage::value_t> key_map = {
    // Letters
    {"a", pqrs::hid::usage::keyboard_or_keypad::keyboard_a},
    {"b", pqrs::hid::usage::keyboard_or_keypad::keyboard_b},
    {"c", pqrs::hid::usage::keyboard_or_keypad::keyboard_c},
    {"d", pqrs::hid::usage::keyboard_or_keypad::keyboard_d},
    {"e", pqrs::hid::usage::keyboard_or_keypad::keyboard_e},
    {"f", pqrs::hid::usage::keyboard_or_keypad::keyboard_f},
    {"g", pqrs::hid::usage::keyboard_or_keypad::keyboard_g},
    {"h", pqrs::hid::usage::keyboard_or_keypad::keyboard_h},
    {"i", pqrs::hid::usage::keyboard_or_keypad::keyboard_i},
    {"j", pqrs::hid::usage::keyboard_or_keypad::keyboard_j},
    {"k", pqrs::hid::usage::keyboard_or_keypad::keyboard_k},
    {"l", pqrs::hid::usage::keyboard_or_keypad::keyboard_l},
    {"m", pqrs::hid::usage::keyboard_or_keypad::keyboard_m},
    {"n", pqrs::hid::usage::keyboard_or_keypad::keyboard_n},
    {"o", pqrs::hid::usage::keyboard_or_keypad::keyboard_o},
    {"p", pqrs::hid::usage::keyboard_or_keypad::keyboard_p},
    {"q", pqrs::hid::usage::keyboard_or_keypad::keyboard_q},
    {"r", pqrs::hid::usage::keyboard_or_keypad::keyboard_r},
    {"s", pqrs::hid::usage::keyboard_or_keypad::keyboard_s},
    {"t", pqrs::hid::usage::keyboard_or_keypad::keyboard_t},
    {"u", pqrs::hid::usage::keyboard_or_keypad::keyboard_u},
    {"v", pqrs::hid::usage::keyboard_or_keypad::keyboard_v},
    {"w", pqrs::hid::usage::keyboard_or_keypad::keyboard_w},
    {"x", pqrs::hid::usage::keyboard_or_keypad::keyboard_x},
    {"y", pqrs::hid::usage::keyboard_or_keypad::keyboard_y},
    {"z", pqrs::hid::usage::keyboard_or_keypad::keyboard_z},
    // Numbers
    {"0", pqrs::hid::usage::keyboard_or_keypad::keyboard_0},
    {"1", pqrs::hid::usage::keyboard_or_keypad::keyboard_1},
    {"2", pqrs::hid::usage::keyboard_or_keypad::keyboard_2},
    {"3", pqrs::hid::usage::keyboard_or_keypad::keyboard_3},
    {"4", pqrs::hid::usage::keyboard_or_keypad::keyboard_4},
    {"5", pqrs::hid::usage::keyboard_or_keypad::keyboard_5},
    {"6", pqrs::hid::usage::keyboard_or_keypad::keyboard_6},
    {"7", pqrs::hid::usage::keyboard_or_keypad::keyboard_7},
    {"8", pqrs::hid::usage::keyboard_or_keypad::keyboard_8},
    {"9", pqrs::hid::usage::keyboard_or_keypad::keyboard_9},
    // Special keys
    {"space", pqrs::hid::usage::keyboard_or_keypad::keyboard_spacebar},
    {"return", pqrs::hid::usage::keyboard_or_keypad::keyboard_return_or_enter},
    {"enter", pqrs::hid::usage::keyboard_or_keypad::keyboard_return_or_enter},
    {"escape", pqrs::hid::usage::keyboard_or_keypad::keyboard_escape},
    {"esc", pqrs::hid::usage::keyboard_or_keypad::keyboard_escape},
    {"tab", pqrs::hid::usage::keyboard_or_keypad::keyboard_tab},
    {"backspace", pqrs::hid::usage::keyboard_or_keypad::keyboard_delete_or_backspace},
    // Arrows
    {"up", pqrs::hid::usage::keyboard_or_keypad::keyboard_up_arrow},
    {"down", pqrs::hid::usage::keyboard_or_keypad::keyboard_down_arrow},
    {"left", pqrs::hid::usage::keyboard_or_keypad::keyboard_left_arrow},
    {"right", pqrs::hid::usage::keyboard_or_keypad::keyboard_right_arrow},
};

// Signal handler for graceful shutdown
void signal_handler(int signal) {
  std::cout << "Received signal " << signal << ", shutting down..." << std::endl;
  exit_flag = true;

  // Close socket
  if (socket_fd >= 0) {
    close(socket_fd);
  }

  // Unlink socket file
  if (!socket_path.empty()) {
    unlink(socket_path.c_str());
  }
}

// Setup VHD client
void setup_vhid_client() {
  vhid_client = std::make_unique<pqrs::karabiner::driverkit::virtual_hid_device_service::client>();

  vhid_client->warning_reported.connect([](auto&& message) {
    std::cerr << "warning: " << message << std::endl;
  });

  vhid_client->connected.connect([&] {
    std::cout << "VHD connected" << std::endl;
    driver_ready = true;

    pqrs::karabiner::driverkit::virtual_hid_device_service::virtual_hid_keyboard_parameters parameters;
    parameters.set_country_code(pqrs::hid::country_code::us);

    vhid_client->async_virtual_hid_keyboard_initialize(parameters);
    vhid_client->async_virtual_hid_pointing_initialize();
  });

  vhid_client->connect_failed.connect([](auto&& error_code) {
    std::cerr << "VHD connect_failed: " << error_code << std::endl;
    driver_ready = false;
  });

  vhid_client->closed.connect([] {
    std::cout << "VHD closed" << std::endl;
    driver_ready = false;
    keyboard_ready = false;
    pointing_ready = false;
  });

  vhid_client->error_occurred.connect([](auto&& error_code) {
    std::cerr << "VHD error_occurred: " << error_code << std::endl;
  });

  vhid_client->driver_activated.connect([](auto&& activated) {
    static std::optional<bool> prev;
    if (prev != activated) {
      std::cout << "VHD driver_activated: " << activated << std::endl;
      prev = activated;
    }
  });

  vhid_client->driver_connected.connect([](auto&& connected) {
    static std::optional<bool> prev;
    if (prev != connected) {
      std::cout << "VHD driver_connected: " << connected << std::endl;
      prev = connected;
    }
  });

  vhid_client->virtual_hid_keyboard_ready.connect([](auto&& ready) {
    static std::optional<bool> prev;
    if (prev != ready) {
      std::cout << "VHD keyboard_ready: " << ready << std::endl;
      keyboard_ready = ready;
      prev = ready;
    }
  });

  vhid_client->virtual_hid_pointing_ready.connect([](auto&& ready) {
    static std::optional<bool> prev;
    if (prev != ready) {
      std::cout << "VHD pointing_ready: " << ready << std::endl;
      pointing_ready = ready;
      prev = ready;
    }
  });

  vhid_client->async_start();
}

// Command handlers
json handle_ping(const json& cmd) {
  json resp;
  resp["id"] = cmd.value("id", 0);
  resp["status"] = "ok";
  resp["timestamp"] = std::time(nullptr);
  return resp;
}

json handle_click(const json& cmd) {
  json resp;
  resp["id"] = cmd.value("id", 0);
  resp["timestamp"] = std::time(nullptr);

  if (!pointing_ready) {
    resp["status"] = "error";
    resp["message"] = "pointing device not ready";
    return resp;
  }

  try {
    int button = cmd.value("button", 1);
    int press_ms = cmd.value("press", 100);

    if (button < 1 || button > 3) {
      resp["status"] = "error";
      resp["message"] = "button must be 1, 2, or 3";
      return resp;
    }

    std::lock_guard<std::mutex> lock(hid_mutex);

    if (vhid_client) {
      // Button down
      {
        pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::pointing_input report;
        report.buttons.insert(button);
        vhid_client->async_post_report(report);
      }

      std::this_thread::sleep_for(std::chrono::milliseconds(press_ms));

      // Button up
      {
        pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::pointing_input report;
        vhid_client->async_post_report(report);
      }

      resp["status"] = "ok";
    } else {
      resp["status"] = "error";
      resp["message"] = "vhid_client not initialized";
    }
  } catch (const std::exception& e) {
    resp["status"] = "error";
    resp["message"] = e.what();
  }

  return resp;
}

json handle_move(const json& cmd) {
  json resp;
  resp["id"] = cmd.value("id", 0);
  resp["timestamp"] = std::time(nullptr);

  if (!pointing_ready) {
    resp["status"] = "error";
    resp["message"] = "pointing device not ready";
    return resp;
  }

  try {
    int x = cmd.value("x", 0);
    int y = cmd.value("y", 0);

    std::lock_guard<std::mutex> lock(hid_mutex);

    if (vhid_client) {
      // Move
      {
        pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::pointing_input report;
        report.x = static_cast<int8_t>(x);
        report.y = static_cast<int8_t>(y);
        vhid_client->async_post_report(report);
      }

      std::this_thread::sleep_for(std::chrono::milliseconds(10));

      // Stop movement
      {
        pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::pointing_input report;
        report.x = 0;
        report.y = 0;
        vhid_client->async_post_report(report);
      }

      resp["status"] = "ok";
    } else {
      resp["status"] = "error";
      resp["message"] = "vhid_client not initialized";
    }
  } catch (const std::exception& e) {
    resp["status"] = "error";
    resp["message"] = e.what();
  }

  return resp;
}

json handle_key(const json& cmd) {
  json resp;
  resp["id"] = cmd.value("id", 0);
  resp["timestamp"] = std::time(nullptr);

  if (!keyboard_ready) {
    resp["status"] = "error";
    resp["message"] = "keyboard device not ready";
    return resp;
  }

  try {
    std::string action = cmd.value("action", "press");
    pqrs::hid::usage::value_t key_usage(0);

    // Get key usage - prefer numeric usage, fallback to string key name
    if (cmd.contains("usage")) {
      key_usage = pqrs::hid::usage::value_t(cmd["usage"].get<int>());
    } else if (cmd.contains("key")) {
      std::string key_name = cmd["key"];
      auto it = key_map.find(key_name);
      if (it == key_map.end()) {
        resp["status"] = "error";
        resp["message"] = "unknown key name: " + key_name;
        return resp;
      }
      key_usage = it->second;
    } else {
      resp["status"] = "error";
      resp["message"] = "missing 'key' or 'usage' field";
      return resp;
    }

    std::lock_guard<std::mutex> lock(hid_mutex);

    if (!vhid_client) {
      resp["status"] = "error";
      resp["message"] = "vhid_client not initialized";
      return resp;
    }

    if (action == "down") {
      // Key down only
      pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::keyboard_input report;
      report.keys.insert(type_safe::get(key_usage));
      vhid_client->async_post_report(report);
    } else if (action == "up") {
      // Key up only
      pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::keyboard_input report;
      vhid_client->async_post_report(report);
    } else if (action == "press") {
      // Key down + up
      {
        pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::keyboard_input report;
        report.keys.insert(type_safe::get(key_usage));
        vhid_client->async_post_report(report);
      }

      std::this_thread::sleep_for(std::chrono::milliseconds(50));

      {
        pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::keyboard_input report;
        vhid_client->async_post_report(report);
      }
    } else if (action == "hold") {
      // Hold for duration
      int press_ms = cmd.value("press", 1000);

      {
        pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::keyboard_input report;
        report.keys.insert(type_safe::get(key_usage));
        vhid_client->async_post_report(report);
      }

      std::this_thread::sleep_for(std::chrono::milliseconds(press_ms));

      {
        pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::keyboard_input report;
        vhid_client->async_post_report(report);
      }
    } else {
      resp["status"] = "error";
      resp["message"] = "unknown action: " + action;
      return resp;
    }

    resp["status"] = "ok";
  } catch (const std::exception& e) {
    resp["status"] = "error";
    resp["message"] = e.what();
  }

  return resp;
}

json handle_command(const json& cmd) {
  try {
    std::string type = cmd.value("type", "");
    
    // DEBUG: Log which handler is being called
    std::cout << "[DEBUG] handle_command type='" << type << "'" << std::endl;

    if (type == "ping") {
      return handle_ping(cmd);
    } else if (type == "click") {
      return handle_click(cmd);
    } else if (type == "move") {
      return handle_move(cmd);
    } else if (type == "key") {
      return handle_key(cmd);
    }

    // Unified handling for "pointing_input" and "keyboard_input" (Karabiner-style)
    if (type == "pointing_input") {
      json resp;
      resp["id"] = cmd.value("id", 0);
      resp["timestamp"] = std::time(nullptr);
      if (!pointing_ready) {
        resp["status"] = "error";
        resp["message"] = "pointing device not ready";
        return resp;
      }
      try {
        int x = cmd.value("x", 0);
        int y = cmd.value("y", 0);
        int vertical_wheel = cmd.value("vertical_wheel", 0);
        int horizontal_wheel = cmd.value("horizontal_wheel", 0);
        int buttons = cmd.value("buttons", 0);
        std::lock_guard<std::mutex> lock(hid_mutex);
        if (vhid_client) {
          pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::pointing_input report;
          report.x = static_cast<int8_t>(x);
          report.y = static_cast<int8_t>(y);
          report.vertical_wheel = static_cast<int8_t>(vertical_wheel);
          report.horizontal_wheel = static_cast<int8_t>(horizontal_wheel);
          // Set buttons as a bitfield (bitmask, 1=left, 2=right, 4=middle, etc.)
          if (buttons != 0) {
            for (int i = 0; i < 8; ++i) {
              if ((buttons & (1 << i)) != 0) {
                report.buttons.insert(i + 1);
              }
            }
          }
          vhid_client->async_post_report(report);
          resp["status"] = "ok";
          resp["message"] = "mouse event sent";
        } else {
          resp["status"] = "error";
          resp["message"] = "vhid_client not initialized";
        }
      } catch (const std::exception& e) {
        resp["status"] = "error";
        resp["message"] = e.what();
      }
      return resp;
    }
    if (type == "keyboard_input") {
      json resp;
      resp["id"] = cmd.value("id", 0);
      resp["timestamp"] = std::time(nullptr);
      if (!keyboard_ready) {
        resp["status"] = "error";
        resp["message"] = "keyboard device not ready";
        return resp;
      }
      try {
        std::vector<int> keys;
        if (cmd.contains("keys") && cmd["keys"].is_array()) {
          keys = cmd["keys"].get<std::vector<int>>();
        } else {
          resp["status"] = "error";
          resp["message"] = "missing or invalid 'keys' field";
          return resp;
        }
        int modifiers = cmd.value("modifiers", 0);
        std::lock_guard<std::mutex> lock(hid_mutex);
        if (vhid_client) {
          pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::keyboard_input report;
          for (const auto& usage : keys) {
            report.keys.insert(static_cast<uint32_t>(usage));
          }
          // Apply modifier bitmask (Karabiner expects individual modifier entries)
          {
            auto apply_modifiers = [](uint32_t m, auto& mods) {
              using modifier = pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::modifier;
              if (m & 0x01) mods.insert(modifier::left_control);
              if (m & 0x02) mods.insert(modifier::left_shift);
              if (m & 0x04) mods.insert(modifier::left_option);
              if (m & 0x08) mods.insert(modifier::left_command);
              if (m & 0x10) mods.insert(modifier::right_control);
              if (m & 0x20) mods.insert(modifier::right_shift);
              if (m & 0x40) mods.insert(modifier::right_option);
              if (m & 0x80) mods.insert(modifier::right_command);
            };
            apply_modifiers(static_cast<uint32_t>(modifiers), report.modifiers);
          }
          vhid_client->async_post_report(report);
          resp["status"] = "ok";
          resp["message"] = "keyboard event sent";
        } else {
          resp["status"] = "error";
          resp["message"] = "vhid_client not initialized";
        }
      } catch (const std::exception& e) {
        resp["status"] = "error";
        resp["message"] = e.what();
      }
      return resp;
    }

    // Unknown command type fallback
    json resp;
    resp["id"] = cmd.value("id", 0);
    resp["status"] = "error";
    resp["message"] = "unknown command type: " + type;
    resp["timestamp"] = std::time(nullptr);
    return resp;
  } catch (const std::exception& e) {
    json resp;
    resp["id"] = cmd.value("id", 0);
    resp["status"] = "error";
    resp["message"] = std::string("exception: ") + e.what();
    resp["timestamp"] = std::time(nullptr);
    return resp;
  }
}

}  // namespace

int main(void) {
  // Setup signal handlers
  std::signal(SIGINT, signal_handler);
  std::signal(SIGTERM, signal_handler);

  // Initialize dispatcher
  pqrs::dispatcher::extra::initialize_shared_dispatcher();

  // Setup VHD client
  std::cout << "Starting VirtualHID client..." << std::endl;
  setup_vhid_client();

  // Determine user ID
  const char* sudo_uid = std::getenv("SUDO_UID");
  uid_t uid = sudo_uid ? static_cast<uid_t>(std::atoi(sudo_uid)) : getuid();

  // Create socket path
  socket_path = "/tmp/macs_vhid_" + std::to_string(uid) + ".sock";

  std::cout << "Creating Unix socket at: " << socket_path << std::endl;

  // Remove stale socket if exists
  unlink(socket_path.c_str());

  // Create socket
  socket_fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (socket_fd < 0) {
    std::cerr << "Failed to create socket: " << strerror(errno) << std::endl;
    return 1;
  }

  // Bind socket
  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, socket_path.c_str(), sizeof(addr.sun_path) - 1);

  if (bind(socket_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
    std::cerr << "Failed to bind socket: " << strerror(errno) << std::endl;
    close(socket_fd);
    return 1;
  }

  // Set permissions
  if (chmod(socket_path.c_str(), 0660) < 0) {
    std::cerr << "Failed to chmod socket: " << strerror(errno) << std::endl;
  }

  if (chown(socket_path.c_str(), uid, 0) < 0) {
    std::cerr << "Failed to chown socket: " << strerror(errno) << std::endl;
  }

  // Listen
  if (listen(socket_fd, 5) < 0) {
    std::cerr << "Failed to listen on socket: " << strerror(errno) << std::endl;
    close(socket_fd);
    unlink(socket_path.c_str());
    return 1;
  }

  std::cout << "Socket server ready. Press Ctrl+C to quit." << std::endl;
  std::cout << "Driver ready: " << driver_ready << std::endl;

  // Main server loop
  while (!exit_flag) {
    fd_set read_fds;
    FD_ZERO(&read_fds);
    FD_SET(socket_fd, &read_fds);

    struct timeval timeout;
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;

    int result = select(socket_fd + 1, &read_fds, nullptr, nullptr, &timeout);

    if (result < 0) {
      if (errno == EINTR) continue;
      std::cerr << "select error: " << strerror(errno) << std::endl;
      break;
    }

    if (result == 0) continue;  // Timeout

    // Accept connection
    int client_fd = accept(socket_fd, nullptr, nullptr);
    if (client_fd < 0) {
      if (errno == EINTR) continue;
      std::cerr << "accept error: " << strerror(errno) << std::endl;
      continue;
    }

    // Read request
    char buffer[4096];
    ssize_t n = read(client_fd, buffer, sizeof(buffer) - 1);

    if (n <= 0) {
      close(client_fd);
      continue;
    }

    buffer[n] = '\0';

    // DEBUG: Log raw received data
    std::cout << "[DEBUG] Raw received (" << n << " bytes): " << buffer << std::endl;

    // Parse and handle command
    json response;
    try {
      json request = json::parse(buffer);
      
      // DEBUG: Log parsed JSON and type field
      std::cout << "[DEBUG] Parsed JSON: " << request.dump() << std::endl;
      if (request.contains("type")) {
        std::cout << "[DEBUG] Type field: '" << request["type"] << "'" << std::endl;
      } else {
        std::cout << "[DEBUG] No 'type' field found in JSON" << std::endl;
      }
      
      response = handle_command(request);
    } catch (const json::parse_error& e) {
      response["status"] = "error";
      response["message"] = std::string("parse error: ") + e.what();
      response["timestamp"] = std::time(nullptr);
    }

    // Send response
    std::string response_str = response.dump();
    write(client_fd, response_str.c_str(), response_str.size());

    close(client_fd);
  }

  // Cleanup
  std::cout << "Cleaning up..." << std::endl;

  vhid_client = nullptr;

  close(socket_fd);
  unlink(socket_path.c_str());

  pqrs::dispatcher::extra::terminate_shared_dispatcher();

  std::cout << "Shutdown complete." << std::endl;

  return 0;
}
