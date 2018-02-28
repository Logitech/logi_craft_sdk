// Copyright 2018 Logitech Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files(the "Software"), 
// to deal in the Software without restriction, including without limitation 
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
// DEALINGS IN THE SOFTWARE.


#include <websocketpp/config/asio_no_tls_client.hpp>
#include <websocketpp/client.hpp>

#include <experimental/filesystem>
#include <fstream>
#include <iostream>
#include <sstream>

#include "json\json.h"

typedef websocketpp::client<websocketpp::config::asio_client> client;

using std::experimental::filesystem::path;
using websocketpp::lib::placeholders::_1;
using websocketpp::lib::placeholders::_2;
using websocketpp::lib::bind;

// pull out the type of messages sent by our config
typedef websocketpp::config::asio_client::message_type::ptr message_ptr;

std::string pluginSessionId;
int x = 0;
int y = 0;
int z = 0;
bool resetToolChange = true;

class OutputToDebugger
{
public:
    virtual ~OutputToDebugger()
    {
        std::string str = m_os.str();
        if (str.back() != '\n')
        {
            str += '\n';
        }

        OutputDebugStringA(str.c_str());
    }

    std::stringstream& Get()
    {
        return m_os;
    }

protected:
    std::stringstream m_os;
};

#define LOG OutputToDebugger().Get()

std::string GetProcessPath()
{
    // Get process name
    char processPath[MAX_PATH + 1];
    GetModuleFileNameA(nullptr, processPath, _countof(processPath));

    return path(processPath).parent_path().string();
}

std::string GetPluginGuid()
{
    std::string guid;

    path guidFile = GetProcessPath();
    guidFile /= "guid.json";

    std::ifstream infile(guidFile.string());
    if (infile.good())
    {
        Json::Value json;
        Json::Reader r;
        if (r.parse(infile, json, false))
        {
            guid = json["GUID"].asString();
        }
        else
        {
            LOG << "Failed to parse 'guid.json' file. Error Message: "
                << r.getFormattedErrorMessages().c_str() << std::endl;
        }
    }

    return guid;
}

std::string EmptyIfEmptyConverter(const std::string &str)
{
    if (str.empty())
    {
        return "EMPTY";
    }
    return str;
}

void on_open(client* c, websocketpp::connection_hdl hdl)
{
    LOG << "on_connect called with hdl: " << hdl.lock().get() << std::endl;

    websocketpp::lib::error_code ec;

    // Obtain the GUID from the guid.json file
    std::string guid = GetPluginGuid();

    LOG << "***" << std::endl;
    LOG << "***" << std::endl;
    LOG << "*** Plugin GUID is: " << EmptyIfEmptyConverter(guid) << std::endl;
    LOG << "***" << std::endl;
    LOG << "***" << std::endl;

    // Send plugin registration message
    Json::Value json;
    json["message_type"] = "register";
    json["plugin_guid"] = guid;
    json["PID"] = (unsigned int)GetCurrentProcessId();
    json["execName"] = "crown_client.exe";
    json["application_version"] = "1.0";

    c->send(hdl, Json::FastWriter().write(json), websocketpp::frame::opcode::value::text, ec);
    if (ec)
    {
        LOG << "Plugin registration failed because: " << ec.message() << std::endl;
    }
}

void on_close(client* c, websocketpp::connection_hdl hdl)
{
    LOG << "on_close called with hdl: " << hdl.lock().get() << std::endl;
}

// This message handler will be invoked once for each incoming message. 
void on_message(client* c, websocketpp::connection_hdl hdl, message_ptr msg)
{
    LOG << "on_message called with hdl: " << hdl.lock().get()
        << " and message: " << msg->get_payload()
        << std::endl;

    Json::Value json;
    Json::Reader reader;
    if (!reader.parse(msg->get_payload(), json, false))
    {
        LOG << "JSON message cannot be parsed because: " << reader.getFormattedErrorMessages();
        return;
    }

    const auto messageType = json["message_type"].asString();

    if (messageType == "register_ack")
    {
        pluginSessionId = json["session_id"].asString();
        resetToolChange = true;
        return;
    }

    if (messageType == "activate_plugin")
    {
        if (resetToolChange)
        {
            Json::Value json;
            json["message_type"] = "tool_change";
            json["session_id"] = pluginSessionId;
            json["tool_id"] = "slider";
            json["reset_options"] = true;

            websocketpp::lib::error_code ec;
            c->send(hdl, Json::FastWriter().write(json), websocketpp::frame::opcode::value::text, ec);
            if (ec)
            {
                LOG << "Sending tool_change failed because: " << ec.message() << std::endl;
                return;
            }
            resetToolChange = false;
        }

        return;
    }

    if (messageType == "crown_turn_event")
    {
        auto ratchetDelta = json["ratchet_delta"].asInt();
        auto delta = json["delta"].asInt();
        auto currentTool = json["task_options"]["current_tool"].asString();
        auto currentToolOption = json["task_options"]["current_tool_option"].asString();

        if (currentTool != "slider")
        {
            return;
        }

        if (currentToolOption == "numbers")
        {
            if (ratchetDelta == 0)
            {
                return;
            }

            // update and clamp value
            x += ((ratchetDelta > 0) ? 1 : -1);
            x = std::min(x, 11);
            x = std::max(-11, x);

            // Tool Update
            {
                Json::Value json;
                json["message_type"] = "tool_update";
                json["session_id"] = pluginSessionId;
                json["show_overlay"] = true;
                json["tool_id"] = currentTool;

                Json::Value toolOptions;
                toolOptions["name"] = currentToolOption;

                if (x == 11)
                {
                    toolOptions["value"] = "Can't go over 11";
                }
                else if (x == -11)
                {
                    toolOptions["value"] = "Too low to show";
                }
                else
                {
                    toolOptions["value"] = std::to_string(x);
                }

                json["tool_options"].append(toolOptions);

                websocketpp::lib::error_code ec;
                c->send(hdl, Json::FastWriter().write(json), websocketpp::frame::opcode::value::text, ec);
                if (ec)
                {
                    LOG << "Sending tool_update failed because: " << ec.message() << std::endl;
                    return;
                }
            }
        }
        else if (currentToolOption == "letters")
        {
            // update and clamp value
            y += ((ratchetDelta > 0) ? 1 : -1);
            y = std::min(y, 25);
            y = std::max(0, y);

            // Tool Update
            {
                Json::Value json;
                json["message_type"] = "tool_update";
                json["session_id"] = pluginSessionId;
                json["show_overlay"] = true;
                json["tool_id"] = currentTool;

                Json::Value toolOptions;

                char value[2] = {((int)'A' + y), '\0'};

                toolOptions["name"] = currentToolOption;
                toolOptions["value"] = value;

                json["tool_options"].append(toolOptions);

                websocketpp::lib::error_code ec;
                c->send(hdl, Json::FastWriter().write(json), websocketpp::frame::opcode::value::text, ec);
                if (ec)
                {
                    LOG << "Sending tool_update failed because: " << ec.message() << std::endl;
                    return;
                }
            }
        }
        else if (currentToolOption == "numbers2")
        {
            z += delta;

            // Tool update
            {
                Json::Value json;
                json["message_type"] = "tool_update";
                json["session_id"] = pluginSessionId;
                json["show_overlay"] = true;
                json["tool_id"] = currentTool;

                Json::Value toolOptions;
                toolOptions["name"] = currentToolOption;
                toolOptions["value"] = std::to_string(z);

                json["tool_options"].append(toolOptions);

                websocketpp::lib::error_code ec;
                c->send(hdl, Json::FastWriter().write(json), websocketpp::frame::opcode::value::text, ec);
                if (ec)
                {
                    LOG << "Sending tool_update failed because: " << ec.message() << std::endl;
                    return;
                }
            }
        }
        return;
    }
}

int main(int argc, char* argv[])
{
    std::string uri = "ws://localhost:10134";

    if (argc == 2)
    {
        uri = argv[1];
    }

    std::cout << "Starting crown_client. \n";
    std::cout << "Press Ctrl + C to quit.\n";

    std::string lastErrorMsg;

    try
    {
        // Create a client endpoint
        client c;

        // Clear logging
        c.clear_access_channels(websocketpp::log::alevel::all);
        c.clear_access_channels(websocketpp::log::alevel::frame_header | websocketpp::log::alevel::frame_payload);

        // Initialize ASIO
        c.init_asio();

        // Register our handlers
        c.set_message_handler(bind(&on_message, &c, ::_1, ::_2));
        c.set_open_handler(bind(&on_open, &c, ::_1));
        c.set_close_handler(bind(&on_close, &c, ::_1));

        websocketpp::lib::error_code ec;
        client::connection_ptr con = c.get_connection(uri, ec);
        if (ec)
        {
            LOG << "could not create connection because: " << ec.message() << std::endl;
            return 0;
        }

        // Note that connect here only requests a connection. No network messages are
        // exchanged until the event loop starts running in the next line.
        c.connect(con);

        // Start the ASIO io_service run loop
        // this will cause a single connection to be made to the server. c.run()
        // will exit when this connection is closed.
        c.run();
    }
    catch (websocketpp::exception const & e)
    {
        if (lastErrorMsg != e.m_msg)
        {
            lastErrorMsg = e.m_msg;
            LOG << lastErrorMsg << std::endl;
        }
    }
}
