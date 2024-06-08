// Power Panel 
// Incremental build-up of Power Dustribution Panel 

integer POWER_CHANNEL = -654647;
integer clock_interval = 1;
float power_sourced = 1000; // how much power we are getting form sources
float power_capacity = 1000; // how much power we can transfer toal

string REQ = "-REQ";
string ACK = "-ACK";
string PING = "Ping";
string CONNECT = "Connect";
string DISCONNECT = "Disconnect";
string POWER = "Power";
string RESET = "Reset";

list device_keys;
list device_names;
list device_draws; // how much power each device wants

integer dialog_channel;
integer dialog_listen;
integer dialog_countdown;

string CLOSE = "Close";
string mainMenu = "Main";
string menuIdentifier;
key menuAgentKey;
integer menuChannel;
integer menuListen;
integer menuTimeout;

integer DEBUG = TRUE;
sayDebug(string message) {
    if (DEBUG) {
        llSay(0,message);
    }
}

string menuCheckbox(string title, integer onOff)
// make checkbox menu item out of a button title and boolean state
{
    string checkbox;
    if (onOff)
    {
        checkbox = "☒";
    }
    else
    {
        checkbox = "☐";
    }
    return checkbox + " " + title;
}

list menuRadioButton(string title, string match)
// make radio button menu item out of a button and the state text
{
    string radiobutton;
    if (title == match)
    {
        radiobutton = "●";
    }
    else
    {
        radiobutton = "○";
    }
    return [radiobutton + " " + title];
}

list menuButtonActive(string title, integer onOff)
// make a menu button be the text or the Inactive symbol
{
    string button;
    if (onOff)
    {
        button = title;
    }
    else
    {
        button = "["+title+"]";
    }
    return [button];
}

string trimMessageButton(string message) {
    string messageButtonsTrimmed = message;
    
    list LstripList = ["☒ ","☐ ","● ","○ "];
    integer i;
    for (i=0; i < llGetListLength(LstripList); i = i + 1) {
        string thing = llList2String(LstripList, i);
        integer whereThing = llSubStringIndex(messageButtonsTrimmed, thing);
        if (whereThing > -1) {
            integer thingLength = llStringLength(thing)-1;
            messageButtonsTrimmed = llDeleteSubString(messageButtonsTrimmed, whereThing, whereThing + thingLength);
        }
    }
    
    return messageButtonsTrimmed;
}

string trimMessageParameters(string message) {
    string messageTrimmed = message;
    integer whereLBracket = llSubStringIndex(message, "[") -1;
    if (whereLBracket > -1) {
        messageTrimmed = llGetSubString(message, 0, whereLBracket);
    }
    return messageTrimmed;
}

string getMessageParameter(string message) {
    integer whereLBracket = llSubStringIndex(message, "[") +1;
    integer whereRBracket = llSubStringIndex(message, "]") -1;
    string parameters = llGetSubString(message, whereLBracket, whereRBracket);
    return parameters;
}

setUpMenu(string identifier, key avatarKey, string message, list buttons)
// wrapper to do all the calls that make a simple menu dialog.
// - adds required buttons such as Close or Main
// - displays the menu command on the alphanumeric display
// - sets up the menu channel, listen, and timer event 
// - calls llDialog
// parameters:
// identifier - sets menuIdentifier, the later context for the command
// avatarKey - uuid of who clicked
// message - text for top of blue menu dialog
// buttons - list of button texts
{
    sayDebug("setUpMenu "+identifier);
    
    if (identifier != mainMenu) {
        buttons = buttons + [mainMenu];
    }
    buttons = buttons + [CLOSE];
    
    menuIdentifier = identifier;
    menuAgentKey = avatarKey; // remember who clicked
    menuChannel = -(llFloor(llFrand(10000)+1000));
    menuListen = llListen(menuChannel, "", avatarKey, "");
    menuTimeout = llFloor(llGetTime()) + 30;
    llDialog(avatarKey, message, buttons, menuChannel);
}

resetMenu() {
    llListenRemove(menuListen);
    menuListen = 0;
    menuChannel = 0;
    menuAgentKey = "";
}

presentMainMenu(key whoClicked) {
    string message = "Power Panel Main Menu";
    list buttons = [RESET, DISCONNECT];
    setUpMenu(mainMenu, whoClicked, message, buttons);
}

presentDisonnectMenu(key whoClicked) {
    string message = "Select Power Consumer to Disconnect:";
    integer i;
    list buttons = [];
    for (i = 0; i < llGetListLength(device_names); i = i + 1) {
        message = message + "\n" + (string)i + " " + llList2String(device_names, i) + " " + llList2String(device_draws, i) + "W";
        sayDebug("presentDisonnectMnu:"+message);
        buttons = buttons + [(string)i];
    }
    setUpMenu(DISCONNECT, whoClicked, message, buttons);    
}


list_devices() {
    integer i;
    for (i = 0; i < llGetListLength(device_keys); i = i + 1) {
        llSay(0, llList2String(device_names, i) + ": " + (string)llList2Integer(device_draws, i)+" watts");
    }
}

add_device(key objectKey, string objectName) {
    integer e = llListFindList(device_keys, [objectKey]);
    if (e > -1) {
        sayDebug("device "+objectName+" was already in ist");
        device_keys = llDeleteSubList(device_keys, e, e);
        device_names = llDeleteSubList(device_names, e, e);
        device_draws = llDeleteSubList(device_draws, e, e);
    }
    device_keys = device_keys + [objectKey];
    device_names = device_names + [objectName];
    device_draws = device_draws + [0];
    llRegionSayTo(objectKey, POWER_CHANNEL, CONNECT+ACK);
    list_devices();
}

request_power(key objectKey, string objectName, string powerLevel) {
    sayDebug(objectName+" requests "+powerLevel+" watts");
}

default
{
    state_entry()
    {
        sayDebug("state_entry");
        llSetTimerEvent(1);
        llListen(POWER_CHANNEL, "", NULL_KEY, "");
    }

    touch_start(integer total_number)
    {
        sayDebug("touch_start");
        key whoClicked  = llDetectedKey(0);
        presentMainMenu(whoClicked);
    }
    
    listen( integer channel, string name, key objectKey, string message )
    {
        sayDebug("listen name:"+name+" message:"+message);
        if (channel == menuChannel) {
            resetMenu();
            if (message == CLOSE) {
                sayDebug("listen Close");
            } else if (message == RESET) {
                sayDebug("listen Reset");
                llResetScript();
            } else if (message == DISCONNECT) {
                presentDisonnectMenu(objectKey);
            } else if (menuIdentifier == DISCONNECT) {
                sayDebug("listen DISCONNECT from "+name+": "+message);
                llRegionSayTo(llList2Key(device_keys, (integer)message), POWER_CHANNEL, DISCONNECT+ACK);
            } else {
                sayDebug("listen did not handle "+message);
            }
        } else if (channel == POWER_CHANNEL) {
            if (message == PING+REQ) {
                sayDebug("ping req");
                llRegionSayTo(objectKey, POWER_CHANNEL, PING+ACK);
            } else if (message == CONNECT+REQ) {
                sayDebug("connect req");
                add_device(objectKey, name);
            } else if (trimMessageParameters(message) == POWER+REQ) {
                sayDebug("power req");
                request_power(objectKey, name, getMessageParameter(message));
            }
        }
    }

    timer() {
        integer now = llFloor(llGetTime());
        if (now > menuTimeout) {
            resetMenu();
        }
    }
}
