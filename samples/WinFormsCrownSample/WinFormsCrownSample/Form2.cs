

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


using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;


using WebSocketSharp;
using Newtonsoft;
using Newtonsoft.Json;
using System.Diagnostics;
using System.Windows.Forms;

using Microsoft.Win32;
using System.IO;
using System.Globalization;
using System.Runtime.InteropServices;


namespace WinFormsCrownSample
{
   
    public partial class Form2 : Form
    {
        public class ToolOption
        {
            public string name { get; set; }
            public string value { get; set; }
        }

        public class ToolUpdateRootObject
        {
            public string message_type { get; set; }
            public string session_id { get; set; }
            public string show_overlay { get; set; }
            public string tool_id { get; set; }
            public List<ToolOption> tool_options { get; set; }
            public string play_task { get; set; }
        }

        public class CrownRegisterRootObject
        {
            public string message_type { get; set; }
            public string plugin_guid { get; set; }
            public string session_id { get; set; }
            public int PID { get; set; }
            public string execName { get; set; }
        }

        public class TaskOptions
        {
            public string current_tool { get; set; }
            public string current_tool_option { get; set; }
        }

        public class CrownRootObject
        {
            public string message_type { get; set; }
            public int device_id { get; set; }
            public int unit_id { get; set; }
            public int feature_id { get; set; }
            public string task_id { get; set; }
            public string session_id { get; set; }
            public int touch_state { get; set; }
            public TaskOptions task_options { get; set; }
            public int delta { get; set; }
            public int ratchet_delta { get; set; }
            public Int64 time_stamp { get; set; }
            public string state { get; set; }
        }

        public class ToolChangeObject
        {
            public string message_type { get; set; }
            public string session_id { get; set; }
            public string tool_id { get; set; }
        }

        public static string sessionId = "";
        public static string lastcontext = "";
        public static bool sendContextChange = false;

        [DllImport("kernel32.dll")]
        public static extern bool ProcessIdToSessionId(uint dwProcessID, int pSessionID);

        [DllImport("Kernel32.dll", EntryPoint = "WTSGetActiveConsoleSessionId")]
        public static extern int WTSGetActiveConsoleSessionId();

        private static WebSocket client;
        public static string host1 = "wss://echo.websocket.org";
        public static string host = "ws://localhost:10134";
        public static List<CrownRootObject> crownObjectList = new List<CrownRootObject>();


        public static void toolChange(string contextName)
        {
            try
            {
                ToolChangeObject toolChangeObject = new ToolChangeObject();
                toolChangeObject.message_type = "tool_change";
                toolChangeObject.session_id = sessionId;
                toolChangeObject.tool_id = contextName;

                string s = JsonConvert.SerializeObject(toolChangeObject);
                client.Send(s);

            }
            catch (Exception ex)
            {
                string err = ex.Message;
            }
        }



        public static void updateUIWithDeserializedData(CrownRootObject crownRootObject)
        {
            //CrownRootObject crownRootObject = JsonConvert.DeserializeObject<CrownRootObject>(msg);
            int len = 0;
            int progressValue = 0;
            if (crownRootObject.message_type == "deactivate_plugin")
                return;

            try
            {
                if (crownRootObject.message_type == "crown_turn_event")
                {
                    // received a crown turn event from Craft crown
                    Trace.Write("++ crown ratchet delta :" + crownRootObject.ratchet_delta + " slot delta = " + crownRootObject.delta + "\n");

                    switch (crownRootObject.task_options.current_tool)
                    {
                        case "ProgressBar":
                            progressValue = m_form2.progressBar1.Value + crownRootObject.delta;

                            if(progressValue < 0)
                            {
                                progressValue = 0;
                            }

                            if(progressValue > 1000)
                            {
                                progressValue = 1000;
                            }

                            m_form2.progressBar1.Invoke(new Action(() => m_form2.progressBar1.Value = progressValue));
                            ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", progressValue.ToString());
                            break;

                        case "NumericUpDown":
                            int numericValue = (int)m_form2.numericUpDown1.Value + crownRootObject.delta;
                            
                            if(numericValue < 0)
                            {
                                numericValue = 0;
                            }

                            if(numericValue > 1000)
                            {
                                numericValue = 1000;
                            }

                            m_form2.numericUpDown1.Invoke(new Action(() => m_form2.numericUpDown1.Value = numericValue));
                            ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", numericValue.ToString());
                            break;

                        case "ListBox":
                            int listIndex = 0;
                            m_form2.listBox1.Invoke(new Action(() =>  listIndex = m_form2.listBox1.SelectedIndex));
                            listIndex = listIndex + crownRootObject.ratchet_delta;

                            if (listIndex < 0)
                            {
                                listIndex = 0;
                            }

                            if (listIndex >950)
                            {
                                listIndex = 950;
                            }
                            m_form2.listBox1.Invoke(new Action(() => m_form2.listBox1.SelectedIndex = listIndex));
                            ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", listIndex.ToString());
                            break;

                        case "TextBox":
                            switch (crownRootObject.task_options.current_tool_option)
                            {
                                case "textBoxHeight":
                                    int textbox_height = 0;
                                    m_form2.textBox1.Invoke(new Action(() => textbox_height = m_form2.textBox1.Height));
                                    len = textbox_height = textbox_height + crownRootObject.delta;
                                    m_form2.textBox1.Invoke(new Action(() => m_form2.textBox1.Height = textbox_height));
                                    break;

                                case "textBoxWidth":
                                    int textbox_width = 0;
                                    m_form2.textBox1.Invoke(new Action(() => textbox_width = m_form2.textBox1.Width));
                                    len = textbox_width = textbox_width + crownRootObject.delta;
                                    m_form2.textBox1.Invoke(new Action(() => m_form2.textBox1.Width = textbox_width));
                                    
                                    break;

                                default:
                                    break;

                            }
                            //ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", len.ToString());
                            break;

                        case "ComboBox":
                            int comboIndex = 0;
                            m_form2.comboBox1.Invoke(new Action(() => comboIndex = m_form2.comboBox1.SelectedIndex));
                            comboIndex = comboIndex + crownRootObject.delta;

                            if (comboIndex < 0)
                            {
                                comboIndex = 0;
                            }

                            if (comboIndex > 950)
                            {
                                comboIndex = 950;
                            }
                            m_form2.listBox1.Invoke(new Action(() => m_form2.comboBox1.SelectedIndex = comboIndex));
                            ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", comboIndex.ToString());
                            break;

                        case "CheckedListBox":
                            int checkedListIndex = 0;
                            m_form2.checkedListBox1.Invoke(new Action(() => checkedListIndex = m_form2.checkedListBox1.SelectedIndex));
                            checkedListIndex = checkedListIndex + crownRootObject.delta;

                            if (checkedListIndex < 0)
                            {
                                checkedListIndex = 0;
                            }

                            if (checkedListIndex > 999)
                            {
                                checkedListIndex = 999;
                            }
                            m_form2.listBox1.Invoke(new Action(() => m_form2.checkedListBox1.SelectedIndex = checkedListIndex));
                            ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", checkedListIndex.ToString());
                            break;

                        case "TrackBar":
                            int trackIndex = 0;
                            m_form2.trackBar1.Invoke(new Action(() => trackIndex = m_form2.trackBar1.Value));
                            trackIndex = trackIndex + crownRootObject.delta;

                            if (trackIndex < 0)
                            {
                                trackIndex = 0;
                            }

                            if (trackIndex > 100)
                            {
                                trackIndex = 100;
                            }
                            
                            m_form2.trackBar1.Invoke(new Action(() => m_form2.trackBar1.Value = trackIndex));
                            ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", trackIndex.ToString());
                            break;

                        case "TabControl":
                            int tabIndex = 1;
                            m_form2.tabControl1.Invoke(new Action(() => tabIndex = m_form2.tabControl1.SelectedIndex));
                            tabIndex = tabIndex + crownRootObject.ratchet_delta;

                            if (tabIndex < 0)
                            {
                                tabIndex = 1;
                            }

                            if (tabIndex > 10)
                            {
                                tabIndex = 10;
                            }
                            m_form2.tabControl1.Invoke(new Action(() => m_form2.tabControl1.SelectedIndex = tabIndex));
                            ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", tabIndex.ToString());
                            break;

                        case "RichTextBox":
                            float richTextIndex = 0;
                            m_form2.richTextBox1.Invoke(new Action(() => richTextIndex = m_form2.richTextBox1.Font.Size));
                            richTextIndex = richTextIndex + crownRootObject.delta;

                            if (richTextIndex < 5)
                            {
                                richTextIndex = 5;
                            }

                            if (richTextIndex > 100)
                            {
                                richTextIndex = 100;
                            }
                            m_form2.richTextBox1.Invoke(new Action(() => m_form2.richTextBox1.Font = new Font(m_form2.richTextBox1.Font.FontFamily, richTextIndex)));
                            ReportToolOptionDataValueChange(crownRootObject.task_options.current_tool, "quickLayout", richTextIndex.ToString());
                            break;

                        default:
                            break;
                    }
                }

            }
            catch (Exception ex)
            {
                string str = ex.Message;
            }

        }

        public  void SetupUIRefreshTimer()
        {
            m_form2 = this;

            System.Timers.Timer timer = new System.Timers.Timer(70);
            timer.Enabled = true;
            timer.Elapsed += new System.Timers.ElapsedEventHandler(timer_Elapsed);
            timer.Start();

            // reconnection watch dog 
            System.Timers.Timer reconnection_timer = new System.Timers.Timer(30000);
            reconnection_timer.Enabled = true;
            reconnection_timer.Elapsed += new System.Timers.ElapsedEventHandler(connection_watchdog_timer);
        }

        public static void connection_watchdog_timer(object sender, System.Timers.ElapsedEventArgs e)
        {
            if (!client.IsAlive)
            {
                client = null;
                connectWithManager();

            }

        }


        public static void timer_Elapsed(object sender, System.Timers.ElapsedEventArgs e)
        {
            try
            {
                
                int totalDeltaValue = 0;
                int totalRatchetDeltaValue = 0;
                if (crownObjectList == null || crownObjectList.Count == 0)
                {
                    //Trace.Write("Queue is empty\n");
                    return;
                }
                else
                {
                    //Trace.Write("Queue size is: " + crownObjectList.Count + "\n");
                }

                string currentToolOption = crownObjectList[0].task_options.current_tool_option;

                //Trace.Write("currentToolOption is: " + currentToolOption + "\n");
                CrownRootObject crownRootObject = crownObjectList[0];
                int count = 0;
                for (int i = 0; i < crownObjectList.Count; i++)
                {
                    if (currentToolOption == crownObjectList[i].task_options.current_tool_option)
                    {
                        totalDeltaValue = totalDeltaValue + crownObjectList[i].delta;
                        totalRatchetDeltaValue = totalRatchetDeltaValue + crownObjectList[i].ratchet_delta;
                    }
                    else
                        break;

                    count++;
                }

                if (crownObjectList.Count >= 1)
                {
                    crownObjectList.Clear();

                    crownRootObject.delta = totalDeltaValue;
                    crownRootObject.ratchet_delta = totalRatchetDeltaValue;
                    //Trace.Write("Ratchet delta is :" + totalRatchetDeltaValue + "\n");
                    updateUIWithDeserializedData(crownRootObject);
                }
            }
            catch (Exception ex)
            {
                string str = ex.Message;
            }
        }

        private delegate void EventHandle();

        public static void wrapperUpdateUI(string msg)
        {
            Trace.Write("msg :" + msg + "\n");
            CrownRootObject crownRootObject = JsonConvert.DeserializeObject<CrownRootObject>(msg);

            if ((crownRootObject.message_type == "crown_turn_event"))
            {
                crownObjectList.Add(crownRootObject);
                Trace.Write("**** UI crown ratchet delta :" + crownRootObject.ratchet_delta + " slot delta = " + crownRootObject.delta + "\n");

             
            }
            else if (crownRootObject.message_type == "register_ack")
            {
                // save the session id as this is used for any communication with Logi Options 
                sessionId = crownRootObject.session_id;
                //toolChange("nothing");
                lastcontext = "";

                if (sendContextChange)
                {
                    sendContextChange = false;
                    toolChange("ProgressBar");
                }
                else
                {

                    toolChange("ProgressBar");
                }

            }
        }

        public static void openUI(string msg)
        {
            string str = msg;
        }

        public static void closeConnection()
        {

        }


        public static void displayError(string msg)
        {
            string str = msg;
        }

        public static void connectWithManager()
        {
            try
            {
                client = new WebSocket(host);

                client.OnOpen += (ss, ee) =>
                    openUI(string.Format("Connected to {0} successfully", host));
                client.OnError += (ss, ee) =>
                    displayError("Error: " + ee.Message);

                client.OnMessage += (ss, ee) =>
                    wrapperUpdateUI(ee.Data);

                client.OnClose += (ss, ee) =>
                    closeConnection();

                client.Connect();

                // build the connection request packet 
                Process currentProcess = Process.GetCurrentProcess();
                CrownRegisterRootObject registerRootObject = new CrownRegisterRootObject();
                registerRootObject.message_type = "register";
                registerRootObject.plugin_guid = "d510af8d-360f-4f3d-9216-20cd4f20f664";
                registerRootObject.execName = "WinFormsCrownSample.exe";
                registerRootObject.PID = Convert.ToInt32(currentProcess.Id);
                string s = JsonConvert.SerializeObject(registerRootObject);


                // only connect to active session process
                registerRootObject.PID = Convert.ToInt32(currentProcess.Id);
                int activeConsoleSessionId = WTSGetActiveConsoleSessionId();
                int currentProcessSessionId = Process.GetCurrentProcess().SessionId;

                // if we are running in active session?
                if (currentProcessSessionId == activeConsoleSessionId)
                {
                    client.Send(s);
                }
                else
                {
                    Trace.TraceInformation("Inactive user session. Skipping connect");
                }


            }
            catch (Exception ex)
            {
                string str = ex.Message;
            }
        }

        public void init()
        {
            try
            {
                // setup timers 
                SetupUIRefreshTimer();

                // setup connnection 
                connectWithManager();
            }
            catch (Exception ex)
            {
                string str = ex.Message;
            }
         
        }
        public static Form2 m_form2;
        
        public Form2()
        {
            InitializeComponent();

            // start the connnection process 
            init();

            progressBar1.Maximum = 1000;
            progressBar1.Step = 1;
            progressBar1.Value = 1;

            numericUpDown1.Minimum = 0;
            numericUpDown1.Maximum = 1000;

            for (int i = 0; i < 951; i++)
            {
                listBox1.Items.Add(i.ToString());
            }
            listBox1.SelectedIndex = 0;

            for (int i = 0; i < 1000; i++)
            {
                comboBox1.Items.Add(i.ToString());
            }
            comboBox1.SelectedIndex = 0;

            for (int i = 0; i < 1000; i++)
            {
                checkedListBox1.Items.Add(i.ToString());
            }
            checkedListBox1.SetItemChecked(0,true);

            trackBar1.Minimum = 0;
            trackBar1.Maximum = 100;
        }

        private void progressBar1_Click(object sender, EventArgs e)
        {
            toolChange("ProgressBar");
        }

        private void numericUpDown1_Click(object sender, EventArgs e)
        {
            toolChange("NumericUpDown");
        }

        private void listBox1_Click(object sender, EventArgs e)
        {
            toolChange("ListBox");
        }

        private void textBox1_Click(object sender, EventArgs e)
        {
            toolChange("TextBox");
        }

        private void comboBox1_Click(object sender, EventArgs e)
        {
            toolChange("ComboBox");
        }

        private void checkedListBox1_Click(object sender, EventArgs e)
        {
            toolChange("CheckedListBox");
        }

        private void trackBar1_MouseDown(object sender, MouseEventArgs e)
        {
            toolChange("TrackBar");
        }

        private void tabControl1_Click(object sender, EventArgs e)
        {
            toolChange("TabControl");
        }

        private void richTextBox1_Click(object sender, EventArgs e)
        {
            toolChange("RichTextBox");
        }

        public static void ReportToolOptionDataValueChange(string tool, string toolOption, string value)
        {
            ToolUpdateRootObject toolUpdateRootObject = new ToolUpdateRootObject
            {
                tool_id = tool,
                message_type = "tool_update",
                session_id = sessionId,
                show_overlay = "true",
                tool_options = new List<ToolOption> { new ToolOption { name = toolOption, value = value } }
            };

            string s = JsonConvert.SerializeObject(toolUpdateRootObject);
            client.Send(s);

            Trace.TraceInformation("MyWebSocket.ReportToolOptionDataValueChange - Tool:{0}, Tool option:{1}, Value:{2} ", tool, toolOption, value);
        }
    }
   
}
