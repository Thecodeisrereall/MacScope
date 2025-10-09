// macscope-vhid.cpp
// Minimal client for Karabiner DriverKit VirtualHIDDevice daemon
// Commands:
//   macscope-vhid ping
//   macscope-vhid create-keyboard --country us|jp|de
//   macscope-vhid key down --usage 0x04
//   macscope-vhid key up   --usage 0x04

#include <pqrs/dispatcher.hpp>
#include <pqrs/karabiner/driverkit/virtual_hid_device_service.hpp>
#include <pqrs/karabiner/driverkit/virtual_hid_device_driver/hid_report/keyboard_input.hpp>
#include <pqrs/hid/usage.hpp>
#include <pqrs/hid/country_code.hpp>

#include <optional>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <cstring>
#include <cstdio>
#include <cstdint>

namespace vhid = pqrs::karabiner::driverkit;

struct args_t {
  std::string cmd;            // "ping"|"create-keyboard"|"key"
  std::string country = "us"; // for create-keyboard
  std::string key_action;     // "down"|"up"
  uint16_t usage = 0x04;      // default 'A'
};

static void print_usage() {
  std::fprintf(stderr,
    "Usage:\n"
    "  macscope-vhid ping\n"
    "  macscope-vhid create-keyboard --country us|jp|de\n"
    "  macscope-vhid key down --usage 0x04\n"
    "  macscope-vhid key up   --usage 0x04\n");
}

static bool parse_hex_or_dec(const char* s, uint16_t& out) {
  if (!s) return false;
  char* end = nullptr;
  unsigned long v = 0;
  if (std::strlen(s) > 2 && s[0]=='0' && (s[1]=='x' || s[1]=='X')) {
    v = std::strtoul(s+2, &end, 16);
  } else {
    v = std::strtoul(s, &end, 10);
  }
  if (end == s || v > 0xFFFF) return false;
  out = static_cast<uint16_t>(v);
  return true;
}

static bool parse_args(int argc, const char** argv, args_t& a) {
  if (argc < 2) return false;
  a.cmd = argv[1];
  if (a.cmd == "ping") {
    return true;
  } else if (a.cmd == "create-keyboard") {
    for (int i=2; i<argc; ++i) {
      if (std::strcmp(argv[i], "--country")==0 && i+1<argc) {
        a.country = argv[++i];
      }
    }
    return true;
  } else if (a.cmd == "key") {
    if (argc < 5) return false;
    a.key_action = argv[2]; // "down" or "up"
    if (std::strcmp(argv[3], "--usage")!=0 || !parse_hex_or_dec(argv[4], a.usage)) {
      return false;
    }
    return true;
  }
  return false;
}

int main(int argc, const char** argv) {
  args_t a;
  if (!parse_args(argc, argv, a)) {
    print_usage();
    return 2;
  }

  // Dispatcher
  pqrs::dispatcher::extra::initialize_shared_dispatcher();
  auto d = pqrs::dispatcher::extra::get_shared_dispatcher();

  // Client
  auto client = std::make_shared<vhid::virtual_hid_device_service::client>(d);

  std::mutex m;
  std::condition_variable cv;
  std::optional<int> rc;
  bool keyboard_ready = false;

  client->connected.connect([&] {
    // On connect, request driver version as a liveness probe (for ping)
    client->async_driver_version_request();

    if (a.cmd == "create-keyboard" || a.cmd == "key") {
      vhid::virtual_hid_device_service::parameters p;

      if (a.country == "us") {
        p.set_country_code(pqrs::hid::country_code::us);
      } else if (a.country == "jp") {
        p.set_country_code(pqrs::hid::country_code::japan);
      } else if (a.country == "de") {
        p.set_country_code(pqrs::hid::country_code::german);
      } else {
        p.set_country_code(pqrs::hid::country_code::us);
      }

      client->async_virtual_hid_keyboard_initialize(p);
    }
  });

  client->driver_version_received.connect([&](auto&& version) {
    // If this is a ping, we can succeed upon receiving version.
    if (a.cmd == "ping") {
      std::unique_lock<std::mutex> lk(m);
      rc = 0;
      cv.notify_one();
    }
  });

  client->virtual_hid_keyboard_ready.connect([&] {
    std::unique_lock<std::mutex> lk(m);
    keyboard_ready = true;
    if (a.cmd == "create-keyboard") {
      rc = 0;
    }
    cv.notify_one();
  });

  client->error_occurred.connect([&](auto&& message, auto&& code) {
    std::unique_lock<std::mutex> lk(m);
    rc = 1;
    cv.notify_one();
  });

  client->closed.connect([&] {
    std::unique_lock<std::mutex> lk(m);
    if (!rc.has_value()) rc = 1;
    cv.notify_one();
  });

  // Start the client
  client->async_start();

  // Wait for readiness depending on command
  {
    std::unique_lock<std::mutex> lk(m);
    if (a.cmd == "ping") {
      cv.wait_for(lk, std::chrono::seconds(5), [&]{ return rc.has_value(); });
    } else {
      cv.wait_for(lk, std::chrono::seconds(5), [&]{ return keyboard_ready || rc.has_value(); });
    }
  }

  // If a key command and keyboard became ready but rc is not set, send report now.
  if (!rc.has_value() && a.cmd == "key") {
    vhid::virtual_hid_device_driver::hid_report::keyboard_input report;
    if (a.key_action == "down") {
      report.keys.insert(static_cast<uint16_t>(a.usage)); // expects uint16_t
    } else {
      // "up" → send empty report (releases)
    }
    client->async_post_report(report);
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    rc = 0;
  }

  pqrs::dispatcher::extra::terminate_shared_dispatcher();
  return rc.value_or(1);
}
