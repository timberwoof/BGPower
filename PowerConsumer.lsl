integer REGISTER_CHANNEL = -654647;
integer register_listen;
string ME;
vector MYPOS;

integer clock_interval = 10;

integer my_channel;
integer my_listen;

string CONNECT  = "connect";
string MYLOCATION = "mylocation";
string YOURLOCATION = "yourlocation";
string POWERSTATUS = "powerstatus";
string POWERUSE = "poweruse";
string REGISTER = "register";
string ASK = "?";
string PHB = "phb";
string OFF = "0";
string ON = "1";

string my_power_status;
float my_power_draw = 100.0;
float my_stability = 1.0;
string my_power_panel;

integer dialog_channel;
integer dialog_listen;
integer dialog_countdown;
integer PHB_status;

sendMessage(integer channel, string to, string command, string parameter)
{
    llRegionSay(channel, to+","+ME+","+command+","+parameter);
}

string updateStatus()
{
    string status = "Designation: " + ME + "\n";
    status = status + "Status: " + (string)my_power_status+ "\n";
    status = status + "Power Draw: "+ (string)my_power_draw+ "\n";
    status = status + "Stability: "+ (string)my_stability+ "\n";
    status = status + "Connected to: "+ my_power_panel+ "\n";

    return status;
}

dialog_result(key agent, string message)
{
    //llWhisper(0,"dialog: "+message);
    // list buttons = ["analyze","test","fix","set feed","set power","switch", "connect", "disconnect"];
    if (message=="analyze")
    {
        llInstantMessage(agent, updateStatus());
    }
    if (message=="test")
    {
        llInstantMessage(agent, updateStatus());
    }
    if (message=="set power")
    {
        // do something to my_power_rating
    }
    if (message=="switch")
    {
        if (my_power_status == ON)
        {
            my_power_status == OFF;
        }
        else
        {
            my_power_status == ON;
        }
        sendMessage(my_channel, my_power_panel, POWERSTATUS, my_power_status);
    }
    if (message=="connect")
    {
        sendMessage(REGISTER_CHANNEL,"*",REGISTER,(string)my_channel);
    }
    if (message=="disconnect")
    {
        llListenRemove(my_channel);
        my_channel = 0;
        my_power_panel = "";
        my_power_status = OFF;
    }

}


default
{
    state_entry()
    {
        ME = llGetObjectDesc();
        MYPOS = llGetPos();
        PHB_status = 0;
        llSetTimerEvent(10);
        register_listen = llListen(REGISTER_CHANNEL,"","","");

        my_channel = 0;
        my_listen = 0;
        my_power_panel = "none";
        my_power_status = OFF;

        sendMessage(REGISTER_CHANNEL, "*", CONNECT, "*");
     }

    touch_start(integer total_number)
    {
        key agent = llDetectedKey(0);
        string message = "Select the maintenance function for this power panel:";
        list buttons = ["analyze","test","fix","set feed","set power","switch", "connect", "disconnect"];
        dialog_channel = llFloor(llFrand(10000));
        dialog_listen = llListen(dialog_channel, "", agent, "");
        llDialog(agent, message, buttons, dialog_channel);
        dialog_countdown = 30;
    }

    listen(integer channel, string name, key agent, string message)
    {
        list parameters = llCSV2List(message);
        // to, from, command, parameter
        string to = llList2String(parameters,0);
        string from = llList2String(parameters,1);
        string command = llList2String(parameters,2);
        string parameter = llList2String(parameters,3);
        //llWhisper(0,to+": "+from+": "+command+": "+parameter);

        if (channel == REGISTER_CHANNEL)
        {
            if (command == CONNECT)
            {
                // I have not registered with any power panel.
                // One is asking me to respond. Set it as my power panel.
                if (my_channel == 0)
                {
                    my_channel = (integer)parameter;
                    my_listen = llListen(my_channel,"","","");
                    my_power_panel = from;
                }
                // I have a power panel.
                // It is asking me to reset my channel to it.
                else if (my_power_panel == from)
                {
                    llListenRemove(my_listen);
                    my_channel = (integer)parameter;
                    my_listen = llListen(my_channel,"","","");
                }
            }
            else if (command == PHB)
            {
                PHB_status = 120; // for two minutes we'll be in PHB mode
            }
        }
        // The message is on the power panel channel.
        // It is to me or to everyone on the channel.
        if ((channel == my_channel) & ((to == ME) | (to == "*")))
        {
            if (command == POWERSTATUS)
            {
                if (parameter == "?")
                {
                    //llWhisper(0,"received powerstatus inquiry");
                    sendMessage(my_channel, from, POWERSTATUS, my_power_status);
                }
                else if (parameter == ON)
                {
                    //llWhisper(0,"received powerstatus set on");
                    my_power_status == parameter;
                    sendMessage(my_channel, from, POWERSTATUS, parameter);
                    sendMessage(my_channel, from, POWERUSE, (string)my_power_draw);
                    llSetColor(<1,1,1>,1);
                }
                else if (parameter == OFF)
                {
                    //llWhisper(0,"received powerstatus set off");
                    my_power_status == parameter;
                    sendMessage(my_channel, from, POWERSTATUS, parameter);
                    llSetColor(<.25,.25,.25>,1);
                }
            }
            else if (command == POWERUSE)
            {
                //llWhisper(0,"received poweruse inquiry");
                if (parameter == "?")
                {
                    sendMessage(my_channel, my_power_panel, POWERUSE, (string)my_power_draw);
                }
            }
            else if (command == YOURLOCATION)
            {
                sendMessage(my_channel, from, MYLOCATION, (string)llGetPos());
            }
            else if ((command == REGISTER) & (from == my_power_panel))
            {
                sendMessage(REGISTER_CHANNEL, my_power_panel, CONNECT, "*");
            }
        }
        else if (channel = dialog_channel)
        {
            llListenRemove(dialog_channel);
            dialog_channel = 0;
            dialog_countdown = -1;
            dialog_result(agent, message);
        }
        llSetText(updateStatus(),<1,1,1>,1);
    }

    timer()
    {
        if (PHB_status > 0)
        {
            PHB_status = PHB_status - clock_interval;
        }

        if (dialog_countdown > 0)
        {
            dialog_countdown = dialog_countdown - clock_interval;
        }
        else if (dialog_countdown == 0)
        {
            llListenRemove(dialog_channel);
            dialog_channel = 0;
            dialog_countdown = -1;
        }

        llSetText(updateStatus(),<1,1,1>,1);
    }
}

