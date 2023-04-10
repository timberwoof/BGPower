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

list device_names;
list power_statuses;
list power_draws;
list distances;
list power_factors;

string my_power_status = ON;
float total_power_draw;
float my_power_rating = 5000.0;
float my_stability = 1.0;

integer dialog_channel;
integer dialog_listen;
integer dialog_countdown;

integer PHB_status;

sendMessage(integer channel, string to, string command, string parameter)
{
    //llWhisper(0,"sending to "+to+": "+command+": "+parameter);
    llRegionSay(channel, to+","+ME+","+command+","+parameter);
}

connect (string from)
{
    integer index = llListFindList(device_names,[from]);
    if (index < 0)
    {
        // new device; add it to the list
        device_names = device_names + [from];
        power_statuses = power_statuses + [OFF];
        power_draws = power_draws + [0];
        distances = distances + [0];
        power_factors = power_factors + [1];
    }
    sendMessage(REGISTER_CHANNEL, from, CONNECT, (string)my_channel);
    sendMessage(REGISTER_CHANNEL, from, YOURLOCATION, ASK);
    sendMessage(REGISTER_CHANNEL, from, POWERSTATUS, ASK);
    sendMessage(REGISTER_CHANNEL, from, POWERUSE, ASK);
}

setMyDistance(string from, string parameter)
{
    integer index = llListFindList(device_names,[from]);
    if (index < 0) // unknown device, kill it
    {
        sendMessage(my_channel,from,POWERSTATUS,OFF);
    }
    else
    {
        vector itsLocation = (vector)parameter;
        float distance = llVecDist(MYPOS, itsLocation);
        distances = llListReplaceList(distances, [distance], index, index);
        float powerFactor = 1.0 + distance / 10.0;
        power_factors = llListReplaceList(distances, [powerFactor], index, index);
    }
}

setMyPowerStatus(string from, string parameter)
{
    integer index = llListFindList(device_names,[from]);
    if (index < 0) // unknown device, kill it
    {
        //llWhisper(0,"deleting unknown device "+from);
        sendMessage(my_channel,from,POWERSTATUS,OFF);
    }
    else
    {
        power_statuses = llListReplaceList(power_statuses, [parameter], index, index);
    }
}

setMyPowerUse(string from, string parameter)
{
    integer index = llListFindList(device_names,[from]);
    if (index < 0) // unknown device, kill it
    {
        sendMessage(my_channel,from,POWERSTATUS,OFF);
    }
    else
    {
        power_draws = llListReplaceList(power_draws, [parameter], index, index);
    }
}

shutDownUsers()
{
}

float calculatePowerDraw()
{
    integer index = 0;
    integer limit = llGetListLength(power_draws);
    float power_draw = 0;
    for (index = 0; index < limit; index++)
    {
        power_draw = power_draw + llList2Float(power_draws,index) * llList2Float(power_factors,index);
    }

    return power_draw;
}

string listDevices()
{
    integer index = 0;
    integer limit = llGetListLength(power_draws);
    string deviceList = "";
    for (index = 0; index < limit; index++)
    {
        deviceList = deviceList + llList2String(device_names, index) +": " +
            (string)llList2Integer(power_statuses,index) + " " +
            (string)llList2Integer(power_draws,index)+"W * " +
            (string)llList2Float(power_factors,index)+" @ "+
            (string)llList2Integer(distances,index)+"m \n";
    }

    return deviceList;
}

string updateStatus()
{
    integer numDevices = llGetListLength(power_draws);
    string status = "Designation: " + ME + "\n";
    status = status + "Devices: "+(string)numDevices+"\n";

    float power_draw = calculatePowerDraw();
    if (power_draw <= my_power_rating)
    {
        my_power_status = ON;
    }
    else
    {
        my_power_status = OFF;
        integer index;
        for (index = 0; index < numDevices; index++)
        {
            string to = llList2String(device_names,index);
            sendMessage(my_channel,to,POWERSTATUS,OFF);
        }
    }

    if (my_power_status == ON)
    {
        status = status + "status: working \n";
    }
    else
    {
        status = status + "status: OFF \n";
    }

    status = status + "Power Draw: "+(string)power_draw + "\n";

    return status;
}

dialog_result(key agent, string message)
{
    //llWhisper(0,"dialog: "+message);
    //  list buttons = ["analyze","test","fix","set feed","set power","set max","switch","disconnect", "register"];
    if (message=="analyze")
    {
        llInstantMessage(agent, listDevices());
    }
    if (message=="test")
    {
        llInstantMessage(agent, updateStatus());
    }
    if (message=="set power")
    {
        // do something to my_power_rating
    }
    if (message=="register")
    {
        sendMessage(REGISTER_CHANNEL,"*",REGISTER,(string)my_channel);
    }

}

default
{
    state_entry()
    {
        ME = llGetObjectDesc();
        MYPOS = llGetPos();

        // Initialize the list because search on 0-length list returns 0.
        device_names = [ME];
        power_statuses = [OFF];
        power_draws = [0];
        distances = [0];
        power_factors = [1];

        PHB_status = 0;

        llSetTimerEvent(clock_interval);

        register_listen = llListen(REGISTER_CHANNEL,"","","");
        my_channel = REGISTER_CHANNEL + llFloor(llFrand(1000));
        my_listen = llListen(my_channel,"","","");

        updateStatus();
    }

    touch_start(integer total_number)
    {
        key agent = llDetectedKey(0);
        string message = "Select the maintenance function for this power panel:";
        list buttons = ["analyze","test","fix","set feed","set power","set max","switch","disconnect","register"];
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
                // Everyone who gets this message waits a random time.
                // Whoever responds first gets the connection.
                llSleep(llFloor(llFrand(10)));
                connect (from);
            }
            else if (command == PHB)
            {
                PHB_status = 120; // for 100 seconds we'll be in PHB mode
            }
        }
        else if (channel == my_channel)
        {
            if (to != ME)
            {
                // it's talking on my channel but it doesn't know my name so turn it off
                sendMessage(my_channel,from,POWERSTATUS,OFF);
            }
            else if (command == CONNECT)
            {
                connect (from);
            }
            else if (command == MYLOCATION)
            {
                setMyDistance(from, parameter);
            }
            else if (command == POWERSTATUS)
            {
                setMyPowerStatus(from, parameter);
                // *** temporary automatic-on!
                if (parameter == OFF)
                {
                    sendMessage(my_channel,from,POWERSTATUS,ON);
                }
            }
            else if (command == POWERUSE)
            {
                setMyPowerUse(from, parameter);
            }
        }
        else if (channel = dialog_channel)
        {
            llListenRemove(dialog_channel);
            dialog_channel = 0;
            dialog_countdown = -1;
            dialog_result(agent, message);
        }
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

