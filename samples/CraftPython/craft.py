
'''
 Copyright 2018 Logitech Inc.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files(the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions :

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
'''

import wx
import websocket
import threading

import os
import json
import uuid
import sys

from copy import deepcopy
from time import sleep
from json import JSONEncoder
from uuid import UUID

glist=[]
crownObjectList = []
toolObject = []
sessionId=""


JSONEncoder_olddefault = JSONEncoder.default

#special encoding for supporting UUID in json payload
def JSONEncoder_newdefault(self, o):
    if isinstance(o, UUID): return str(o)
    return JSONEncoder_olddefault(self, o)

JSONEncoder.default = JSONEncoder_newdefault

connectMessage = {
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": "ProgressBar"
        }


class CraftClient(object):

    def __init__(self):
        self.executableName=""
        self.manifestPath=""
        self.callback=""

    def on_message(self,ws, message):
        print("on_message called...")
        # craft events come in as json objects
        craftEventObj = json.loads(message)
        self.wrapperUpdateUI(craftEventObj)

    def on_close(self,ws):
        print("### closed ###")

    def on_open(self,ws):
        print("on_open called...")
        uid = "6202f2fb-834c-4393-a95f-f5051171e3ec"
        pid = os.getpid()

        connectMessage = {
            "message_type": "register",
            "plugin_guid": "6202f2fb-834c-4393-a95f-f5051171e3ec",
            "PID": pid,
            "execName": self.executableName,
            "manifestPath": self.manifestPath
        }

        regMsg =  json.dumps(connectMessage)
        ws.send(regMsg.encode('utf8'))

    def connect(self, execName,manifestFilePath):
        print("connect called...")
        global ws
        self.executableName = execName
        self.manifestPath = manifestFilePath

        websocket.enableTrace(True)

        ws = websocket.WebSocketApp("ws://127.0.0.1:10134",
                                 on_open = self.on_open,
                                 on_message = self.on_message,
                                 on_close = self.on_close)


        wst = threading.Thread(target=ws.run_forever)
        wst.daemon = True
        wst.start()

    def registerEventHandler(self,cb):
        self.callback = cb

    def wrapperUpdateUI(self,msg):
        global glist,sessionId
        totalDeltaValue=0
        totalRatchetDeltaValue=0
        count=0
        listCount=0
        global firstObject

        if(msg['message_type'] == "crown_turn_event"):
            glist.append(msg)
            listCount = len(glist)
            if listCount==0:
                return
            currentToolOption = glist[0]['task_options']['current_tool_option']
            print("+++currentToolOption = ",currentToolOption)
            print("listCount = ",listCount)
            firstObject = glist[0]
            for i in range(listCount):
                if currentToolOption == glist[i]['task_options']['current_tool_option']:
                    totalDeltaValue = totalDeltaValue = glist[i]['delta']
                    totalRatchetDeltaValue = totalRatchetDeltaValue + glist[i]['ratchet_delta']
                else:
                    break
                count += 1

            if listCount >= 0:
                glist.clear()
            print("totalDeltaValue = ",totalDeltaValue)
            print("firstObject = ",firstObject['message_type'])
            if firstObject['message_type'] == "deactivate_plugin":
                return

            try:
                if firstObject['message_type'] == "crown_turn_event":
                    print("turn event =====")
                    if firstObject['task_options']['current_tool'] == 'Slider':
                        print("\n","selected slider")
                        v = slider.GetValue()
                        tvalue = v + totalDeltaValue
                        slider.SetValue(tvalue)
                    elif firstObject['task_options']['current_tool'] == 'SpinCtrl':
                        print("\n","selected SpinCtrl")
                        v = spin.GetValue()
                        tvalue = v + totalDeltaValue
                        spin.SetValue(tvalue)
                    elif firstObject['task_options']['current_tool'] == 'Gauge':
                        print("\n","selected Gauge")
                        v = gauge.GetValue()
                        tvalue = v + totalDeltaValue
                        gauge.SetValue(tvalue)
                    elif firstObject['task_options']['current_tool'] == 'ComboBox':
                        print("\n","selected ComboBox")
                        v = combo.GetSelection()
                        tvalue = v + totalRatchetDeltaValue
                        combo.SetSelection(tvalue)
                    elif firstObject['task_options']['current_tool'] == 'TextCtrl':
                        print("\n","selected TextCtrl")
                        v = txt.GetSize()
                        h = v.height + totalDeltaValue
                        w = v.width + totalDeltaValue
                        txt.SetSize(w,h)

                    elif firstObject['task_options']['current_tool'] == 'ListBox':
                        print("\n","selected ListBox")
                        v = lb.GetSelection()
                        v = v + totalRatchetDeltaValue
                        lb.SetSelection(v)

            except ValueError:
                print("Error: update UI")



        elif (msg['message_type'] == "register_ack"):
            print("register_ack = ",msg['message_type'])
            sessionId = msg['session_id']
            print("Session Id = ",sessionId)

            connectMessage = {
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": "Slider"
        }
            regMsg =  json.dumps(connectMessage)
            ws.send(regMsg.encode('utf8'))

class TestFrame(wx.Frame):

    def __init__(self, parent, id):
        global craft,slider,spin,gauge,combo,txt,lb
        wx.Frame.__init__(self, parent, id,"Craft Python SDK Sample", size=(800,400))
        panel = wx.Panel(self)
        #lbl = wx.StaticText(panel,-1,"Slider",(10,20))
        lbl = wx.StaticText(panel,-1,label="text",pos=(10,20),size=(50,-1))
        lbl.SetLabel("Slider")

        slider=wx.Slider(panel,-1,0,1,1000,(100,20),(200,-1))
        slider.Bind(wx.EVT_LEFT_UP, self.onClick)

        lbl = wx.StaticText(panel,-1,label="text",pos=(10,100),size=(50,-1))
        lbl.SetLabel("SpinCtrl")

        spin = wx.SpinCtrl(panel,-1,"",pos=(100,100),size=(200,-1),min=0,max=1000)
        spin.Bind(wx.EVT_LEFT_UP, self.spinCtrlClick)

        lbl = wx.StaticText(panel,-1,label="text",pos=(10,180),size=(50,-1))
        lbl.SetLabel("Gauge")

        gauge = wx.Gauge(panel, -1, range=500,pos=(100,180),size=(200,25))
        gauge.Bind(wx.EVT_LEFT_UP, self.gaugeClick)

        lbl = wx.StaticText(panel,-1,label="text",pos=(10,260),size=(50,-1))
        lbl.SetLabel("ComboBox")

        l=[]
        for i in range(0,1000):
          l.append(str(i))
        combo = wx.ComboBox(panel, -1, "",pos=(100,260), size=(200,25), choices=l)
        combo.Bind(wx.EVT_LEFT_UP, self.comboBoxClick)

        lbl = wx.StaticText(panel,-1,label="text",pos=(400,20),size=(50,-1))
        lbl.SetLabel("TextCtrl")

        vtxt = "This is text.This is text.This is text.This is text.This is text.This is text."
        txt = wx.TextCtrl(panel, -1, vtxt, pos=(480,20),size=(100,-1))
        txt.Bind(wx.EVT_LEFT_UP, self.textCtrlClick)

        lbl = wx.StaticText(panel,-1,label="text",pos=(400,180),size=(50,-1))
        lbl.SetLabel("ListBox")

        li =[]
        for i in range(0,1000):
            li.append(str(i))

        lb = wx.ListBox(panel, -1, pos=(480,180),size=(100,-1),choices=li)
        lb.Bind(wx.EVT_LEFT_UP, self.listBoxClick)

    def listBoxClick(self, event):
        print("ListBox clicked...",sessionId)
        connectMessage = {
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": "ListBox"
        }
        regMsg =  json.dumps(connectMessage)
        ws.send(regMsg.encode('utf8'))
        event.Skip()

    def textCtrlClick(self, event):
        print("TextCtrl clicked...",sessionId)
        connectMessage = {
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": "TextCtrl"
        }
        regMsg =  json.dumps(connectMessage)
        ws.send(regMsg.encode('utf8'))
        #self.changeTool("Slider",sessionId)
        event.Skip()

    def comboBoxClick(self, event):
        print("ComboBox clicked...",sessionId)
        connectMessage = {
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": "ComboBox"
        }
        regMsg =  json.dumps(connectMessage)
        ws.send(regMsg.encode('utf8'))
        #self.changeTool("Slider",sessionId)
        event.Skip()

    def gaugeClick(self, event):
        print("Gauge clicked...",sessionId)
        connectMessage = {
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": "Gauge"
        }
        regMsg =  json.dumps(connectMessage)
        ws.send(regMsg.encode('utf8'))
        #self.changeTool("Slider",sessionId)
        event.Skip()

    def onClick(self, event):
        print("Slider clicked...",sessionId)
        connectMessage = {
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": "Slider"
        }
        regMsg =  json.dumps(connectMessage)
        ws.send(regMsg.encode('utf8'))
        #self.changeTool("Slider",sessionId)
        event.Skip()

    def spinCtrlClick(self, event):
        print("SpinCtrl clicked...")
        #self.changeTool("Slider",sessionId)
        connectMessage = {
            
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": "SpinCtrl"
        }
        regMsg =  json.dumps(connectMessage)
        ws.send(regMsg.encode('utf8'))
        event.Skip()

    def changeTool(self,name,sessionId):
        connectMessage = {
            "message_type": "tool_change",
            "session_id": sessionId,
            "tool_id": name
        }
        connectMessage['session_id'] = sessionId
        connectMessage['tool_id'] = name
        regMsg =  json.dumps(connectMessage)
        ws.send(regMsg.encode('utf8'))


if __name__ == '__main__':
    global ws
    global craft

    app = wx.App()
    frame = TestFrame(parent=None, id=-1)
    frame.Show()

    craft = CraftClient()
    craft.connect("Craft.exe", "")


app.MainLoop()




