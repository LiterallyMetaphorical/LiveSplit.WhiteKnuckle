state("White Knuckle") { }

startup
{
    #region ASL Helper Setup
    //Load asl-help binary and instantiate it - will inject code into the asl in the background
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    //Set the helper to load the scene manager, you probably want this (the helper is set at vars.Helper automagically)
    vars.Helper.LoadSceneManager = true;
    //Setting Game Name and toggling alert to ensure runner is comparing against Game TIme
    vars.Helper.GameName = "White Knuckle";
    vars.Helper.AlertLoadless();

    vars.SplitCooldownTimer = new Stopwatch();
    vars.RecentSessionEventPrint = "No Events Yet This Session";
    vars.recentSessionEventSplit = "No Events Yet This Session";

    vars.Watch = (Action<IDictionary<string, object>, IDictionary<string, object>, string>)((oldLookup, currentLookup, key) =>
    {
        // here we see a wild typescript dev attempting C#... oh, the humanity...
        var currentValue = currentLookup.ContainsKey(key) ? (currentLookup[key] ?? "(null)") : null;
        var oldValue = oldLookup.ContainsKey(key) ? (oldLookup[key] ?? "(null)") : null;

    /*Debugging
        // print if there's a change
        if (oldValue != null && currentValue != null && !oldValue.Equals(currentValue)) {vars.Log(key + ": " + oldValue + " -> " + currentValue);}
        // first iteration, print starting values
        if (oldValue == null && currentValue != null) {vars.Log(key + ": " + currentValue);}
    */

    });
    #endregion

	#region TextComponent
    //Dictionary to cache created/reused layout components by their left-hand label (Text1)
    vars.lcCache = new Dictionary<string, LiveSplit.UI.Components.ILayoutComponent>();

    //Function to set (or update) a text component
    vars.SetText = (Action<string, object>)((text1, text2) =>
{
    const string FileName = "LiveSplit.Text.dll";
    LiveSplit.UI.Components.ILayoutComponent lc;

    //Try to find an existing layout component with matching Text1 (label)
    if (!vars.lcCache.TryGetValue(text1, out lc))
    {
        lc = timer.Layout.LayoutComponents.Reverse().Cast<dynamic>()
            .FirstOrDefault(llc => llc.Path.EndsWith(FileName) && llc.Component.Settings.Text1 == text1)
            ?? LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent(FileName, timer);

        //Cache it for later reference
        vars.lcCache.Add(text1, lc);
    }

    //If it hasn't been added to the layout yet, add it
    if (!timer.Layout.LayoutComponents.Contains(lc))
        timer.Layout.LayoutComponents.Add(lc);

    //Set the label (Text1) and value (Text2) of the text component
    dynamic tc = lc.Component;
    tc.Settings.Text1 = text1;
    tc.Settings.Text2 = text2.ToString();
});

    //Function to remove a single text component by its label
    vars.RemoveText = (Action<string>)(text1 =>
{
    LiveSplit.UI.Components.ILayoutComponent lc;

    //If it's cached, remove it from the layout and the cache
    if (vars.lcCache.TryGetValue(text1, out lc))
    {
        timer.Layout.LayoutComponents.Remove(lc);
        vars.lcCache.Remove(text1);
    }
});

    //Function to remove all text components that were added via this script
    vars.RemoveAllTexts = (Action)(() =>
{
    //Remove each one from the layout
    foreach (var lc in vars.lcCache.Values)
        timer.Layout.LayoutComponents.Remove(lc);

    //Clear the cache
    vars.lcCache.Clear();
});
#endregion

    #region setting creation
	//Autosplitter Settings Creation
	dynamic[,] _settings =
	{
    {"textDisplay",                                 true, "Text Options",                                       null},
    {"removeTexts",                                 true, "Remove all texts on exit",                           "textDisplay"},
	{"AutoReset",                                   true, "Automatically reset timer after Restarting run",     null},
	{"AutosplitOptions",                            true, "Autosplit Options",                                  null},
        {"DefaultSplits",                           true, "Campaign split logic implemented by Holly (WK Dev)", "AutosplitOptions"},
            //Campaign
            { "silos-saferoom-enter",               true, "Enter Silo's Safe Room",                     "DefaultSplits"},
            { "i1-pressureseal",                    true, "Activate Interlude 1 Pressure Seal",         "DefaultSplits"},
            { "i1-elevatorroom",                    true, "Enter Interlude 1 Elevator Room",            "DefaultSplits"},
            { "i1-pipeworksenter",                  true, "Enter Pipeworks",                            "DefaultSplits"},
            {"Finish Pipeworks Drainage System",    true, "Finish Pipeworks Drainage System",           "DefaultSplits"},
            { "i2-enter",                           true, "Begin Interlude 2",                          "DefaultSplits"},
            { "i2-ceilinghatch-enter",              true, "Climb Through Ceiling Hatch (Interlude 2)",  "DefaultSplits"},
            { "i2-saferoom-enter",                  true, "Enter Interlude 2 Safe Room",                "DefaultSplits"},
            { "hab-shaft-end",                      true, "Reach End of Habitat Shaft",                 "DefaultSplits"},
            {"Finish Haunted Pier",                 true, "Finish Haunted Pier",                        "DefaultSplits"},
            { "hab-lab-entervents",                 true, "End Game",                                   "DefaultSplits"},
            { "hab-finish",                         true, "Complete Habitat Section",                   "DefaultSplits"},
        {"HollyTutSplits",                          true, "Tutorial split logic implemented by Holly (WK Dev)", "AutosplitOptions"},
            //Tutorial
            { "tut-crouch",                         true, "Tutorial | Crouch",          "HollyTutSplits"},
            { "tut-momentumstart",                  true, "Tutorial | Point to Point",  "HollyTutSplits"},
            { "tut-staminastart",                   true, "Tutorial | Momentum",        "HollyTutSplits"},
            { "tut-enteritems",                     true, "Tutorial | Stamina",         "HollyTutSplits"},
            { "tut-pitonend",                       true, "Tutorial | Pitons",          "HollyTutSplits"},
            { "tut-rebarstart",                     true, "Tutorial | Pockets",         "HollyTutSplits"},
            { "tut-win",                            true, "Tutorial | Win",             "HollyTutSplits"},

		{"RegionSplit",                             false, "Split on every Region change",      "AutosplitOptions"},
        {"AdditionalSubregionSplits",               false, "Split on specific Subregions",      "AutosplitOptions"},
            {"Finish Silos Safe Room",              false, "Finish Silos Safe Room",            "AdditionalSubregionSplits"},
            //{"Finish Pipeworks Drainage System",    false, "Finish Pipeworks Drainage System",  "AdditionalSubregionSplits"},
            {"Finish Intelude: Lockdown",           false, "Finish Intelude: Lockdown",         "AdditionalSubregionSplits"},
            {"Finish Intelude: Ascent",             false, "Finish Intelude: Ascent",           "AdditionalSubregionSplits"},
            {"Finish Habitation Safe Area",         false, "Finish Habitation Safe Area",       "AdditionalSubregionSplits"},
            {"Finish Habitation Service Shaft",     false, "Finish Habitation Service Shaft",   "AdditionalSubregionSplits"},
            //{"Finish Haunted Pier",                 false, "Finish Haunted Pier",               "AdditionalSubregionSplits"},
            {"Finish Delta Labs Lobby",             false, "Finish Delta Labs Lobby",           "AdditionalSubregionSplits"},
            {"Finish Delta Labs",                   false, "Finish Delta Labs",                 "AdditionalSubregionSplits"},
	{"VariableInformation",                         true, "Variable Information",               null},
		{"GameInfo",                                true, "Player Info",                        "VariableInformation"},
			{"Run Peak Ascent",                     false, "Player Peak Ascent of this run",    "GameInfo"},
			{"Ascent Rate",                         true, "Ascent Rate of this run",            "GameInfo"},
            {"Most Recent Session Event",           true, "Displays the latest session event",  "GameInfo"},
		{"LevelInfo",                               true, "Level Info",                         "VariableInformation"},
			{"Region Name",                         false, "Current Region Name",               "LevelInfo"},
			{"Subregion Name",                      true, "Current Subregion Name",             "LevelInfo"},
			{"Level Name",                          true, "Current Level Name",                 "LevelInfo"},
		{"UnitySceneInfo",                          false, "Unity Scene Info",                  "VariableInformation"},
			{"LoadingSceneName",                    false, "Loading Scene Name",                "UnitySceneInfo"},
			{"ActiveSceneName",                     false, "Active Scene Name",                 "UnitySceneInfo"},
	};
	vars.Helper.Settings.Create(_settings);
    #endregion
}

init
{
    //helps clear some errors when null
    current.Scene = "";
    current.activeScene = "";
    current.loadingScene = "";
    current.levelName = "";
    current.regionName = "";
    current.subregionName = "";
    current.playerAscent = 0;
    current.playerAscentPretty = 0;
    current.ascentRatePretty = 0;
    current.IGT = 0;

#region var setup
    //Starting the timer for the splitter cooldown
    vars.SplitCooldownTimer.Start();
    //Helper function that sets or removes text depending on whether the setting is enabled - only works in `init` or later because `startup` cannot read setting values
    vars.SetTextIfEnabled = (Action<string, object>)((text1, text2) =>
{
    if (settings[text1])            //If the matching setting is checked
        vars.SetText(text1, text2); //Show the text
    else
        vars.RemoveText(text1);     //Otherwise, remove it
});

    //This is where we will load custom properties from the code
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
    vars.Helper["IGT"] = mono.Make<float>("CL_GameManager", "gMan", "gameTime");
    vars.Helper["sessionEvent"] = mono.MakeList<IntPtr>("SpeedrunManager", "sessionEvents");
    vars.Helper["playerAscent"] = mono.Make<float>("CL_GameManager", "gMan", "playerAscent");
    vars.Helper["ascentRate"] = mono.Make<float>("CL_GameManager", "gMan", "ascentRate");
    vars.Helper["levelName"] = mono.MakeString("CL_EventManager", "currentLevel", "levelName");
    vars.Helper["regionName"] = mono.MakeString("CL_EventManager", "currentRegion", "regionName");
    vars.Helper["subregionName"] = mono.MakeString("CL_EventManager", "currentSubregion", "subregionName");
    return true;
    });

    //Enable if having scene print issues - a custom function defined in init, the `scene` is the scene's address (e.g. vars.Helper.Scenes.Active.Address)
    vars.ReadSceneName = (Func<IntPtr, string>)(scene => {
    string name = vars.Helper.ReadString(256, ReadStringType.UTF8, scene + 0x38);
    return name == "" ? null : name;
    });
#endregion
}

update
{
    vars.Watch(old, current, "IGT");
    vars.Watch(old, current, "playerAscent");
    vars.Watch(old, current, "ascentRate");
    vars.Watch(old, current, "levelName");
    vars.Watch(old, current, "regionName");
    vars.Watch(old, current, "subregionName");
    vars.Watch(old, current, "sessionEvent");

    //yayyyy lists!!!!!
    if (vars.Helper["sessionEvent"].Current.Count > vars.Helper["sessionEvent"].Old.Count)
	{
        string id = vars.Helper.ReadString(vars.Helper["sessionEvent"].Current[vars.Helper["sessionEvent"].Current.Count - 1]+ 0x10);
        float time = vars.Helper.Read<float>(vars.Helper["sessionEvent"].Current[vars.Helper["sessionEvent"].Current.Count - 1]+ 0x18);
        vars.Log("Session Event: " + id + " - " + time);
        vars.RecentSessionEventPrint = (id + " @ " + time + "s");
	}
    
        //error handling
    if(current.subregionName    == null)    {current.subregionName  = "null";}
    if(current.regionName       == null)    {current.regionName     = "null";}

    //Setting up pretty versions of Peak Ascent and Ascent Rate, starting with Peak Ascent
    if(current.playerAscent > 0 && current.playerAscent     <= 100)     {current.playerAscentPretty = current.playerAscent.ToString().Substring(0, current.playerAscent.ToString().Length - 4);} //vars.Log("Over 0m & equal or under 100m, Removing 4 Characters from end of string");
    if(current.playerAscent > 100 && current.playerAscent   <= 1000)    {current.playerAscentPretty = current.playerAscent.ToString().Substring(0, current.playerAscent.ToString().Length - 3);}//vars.Log("Over 100m & equal or under 1,000m, Removing 3 Characters from end of string");
    if(current.playerAscent > 1000 && current.playerAscent  <= 10000)   {current.playerAscentPretty = current.playerAscent.ToString().Substring(0, current.playerAscent.ToString().Length - 1);}//vars.Log("Over 1000m & equal or under 10,000m, Removing 1 Character from end of string");
    if(current.playerAscent > 10000 && current.playerAscent <= 100000)  {current.playerAscentPretty = current.playerAscent;}//vars.Log("Over 10,000m & equal or under 100,000m, no longer removing characters from end of string");
    //Now for ascentRate
    if(current.ascentRate   > 0 && current.ascentRate       <= 1)       {current.ascentRatePretty = current.ascentRate.ToString().Substring(0, current.playerAscent.ToString().Length - 3);}//vars.Log("Over 0m/s & equal or under 1m/s, Removing 2 Characters from end of string");
    if(current.ascentRate   > 1 && current.ascentRate       <= 9.99)    {current.ascentRatePretty = current.ascentRate.ToString().Substring(0, current.playerAscent.ToString().Length - 4);}//vars.Log("Over 1m/s & equal or under 9.9m/s, Removing 4 Characters from end of string");
    if(current.ascentRate   >= 10 && current.ascentRate     <= 100)     {current.ascentRatePretty = current.ascentRate.ToString().Substring(0, current.playerAscent.ToString().Length - 3);}//vars.Log("Equal or over 10m/s & equal or under 100m/s, Removing 3 Characters from end of string");

    //Get the current active scene's name and set it to `current.activeScene` - sometimes, it is null, so fallback to old value
    current.activeScene = vars.Helper.Scenes.Active.Name ?? current.activeScene;
    //Usually the scene that's loading, a bit jank in this version of asl-help
    current.loadingScene = vars.Helper.Scenes.Loaded[0].Name ?? current.loadingScene;
    if(!String.IsNullOrWhiteSpace(vars.Helper.Scenes.Active.Name))    current.activeScene = vars.Helper.Scenes.Active.Name;
    if(!String.IsNullOrWhiteSpace(vars.Helper.Scenes.Loaded[0].Name))    current.loadingScene = vars.Helper.Scenes.Loaded[0].Name;
    if(current.activeScene != old.activeScene) vars.Log("active: Old: \"" + old.activeScene + "\", Current: \"" + current.activeScene + "\"");
    if(current.loadingScene != old.loadingScene) vars.Log("loading: Old: \"" + old.loadingScene + "\", Current: \"" + current.loadingScene + "\"");

    //Log changes to the active scene
    if (old.activeScene != current.activeScene) {vars.Log("activeScene: " + old.activeScene + " -> " + current.activeScene);}
    if (old.loadingScene != current.loadingScene) {vars.Log("loadingScene: " + old.loadingScene + " -> " + current.loadingScene);}

    //More text component stuff - checking for setting and then generating the text. No need for .ToString since we do that previously
    vars.SetTextIfEnabled("Region Name",current.regionName);
    vars.SetTextIfEnabled("Subregion Name",current.subregionName);
    vars.SetTextIfEnabled("Level Name",current.levelName);
    vars.SetTextIfEnabled("Run Peak Ascent",current.playerAscentPretty + " Meters");
    vars.SetTextIfEnabled("Ascent Rate",current.ascentRatePretty + " M/s");
    vars.SetTextIfEnabled("LoadingSceneName",current.loadingScene);
    vars.SetTextIfEnabled("ActiveSceneName",current.activeScene);
    vars.SetTextIfEnabled("Most Recent Session Event",vars.RecentSessionEventPrint);
}

onStart
{
    vars.Log("activeScene: " + current.activeScene);
    vars.Log("loadingScene: " + current.loadingScene);
    vars.RecentSessionEventPrint = "No Events Yet This Session";
    vars.recentSessionEventSplit = "No Events Yet This Session";
}

start
{
    if (current.IGT > 0 && current.IGT <= 2 && current.activeScene != "Main-Menu")
    {
        if (current.levelName != "Training_Level_01")
        {
            vars.SplitCooldownTimer.Restart();
        }
        return true;
    }
    return false;
}

split
{
    if(vars.SplitCooldownTimer.Elapsed.TotalSeconds < 10) {return false;}

    //Full Game Holly Splits
    if (vars.Helper["sessionEvent"].Current.Count > vars.Helper["sessionEvent"].Old.Count)
	{
		string id = vars.Helper.ReadString(vars.Helper["sessionEvent"].Current[vars.Helper["sessionEvent"].Current.Count - 1] + 0x10);
        vars.recentSessionEventSplit = id;
		if 
        (
            settings["silos-saferoom-enter"]  && vars.recentSessionEventSplit == "silos-saferoom-enter"  ||
            settings["i1-pressureseal"]       && vars.recentSessionEventSplit == "i1-pressureseal"       ||
            settings["i1-elevatorroom"]       && vars.recentSessionEventSplit == "i1-elevatorroom"       ||
            settings["i1-pipeworksenter"]     && vars.recentSessionEventSplit == "i1-pipeworksenter"     ||
            settings["i2-enter"]              && vars.recentSessionEventSplit == "i2-enter"              ||
            settings["i2-ceilinghatch-enter"] && vars.recentSessionEventSplit == "i2-ceilinghatch-enter" ||
            settings["i2-saferoom-enter"]     && vars.recentSessionEventSplit == "i2-saferoom-enter"     ||
            settings["hab-shaft-end"]         && vars.recentSessionEventSplit == "hab-shaft-end"         || //Gets triggered 3 times, check other files to at least make sure its consistent
            settings["hab-lab-entervents"]    && vars.recentSessionEventSplit == "hab-lab-entervents"    || //Gets triggered 3 times, check other files to at least make sure its consistent
            settings["hab-finish"]            && vars.recentSessionEventSplit == "hab-finish"
        ) 
        {vars.SplitCooldownTimer.Restart();return true;}
    }

    //Tutorial Splits
    if (vars.Helper["sessionEvent"].Current.Count > vars.Helper["sessionEvent"].Old.Count)
	{
		string id = vars.Helper.ReadString(vars.Helper["sessionEvent"].Current[vars.Helper["sessionEvent"].Current.Count - 1] + 0x10);
        vars.recentSessionEventSplit = id;
		if 
        (
            settings["tut-crouch"]        && vars.recentSessionEventSplit == "tut-crouch" ||
            settings["tut-momentumstart"] && vars.recentSessionEventSplit == "tut-momentumstart" ||
            settings["tut-staminastart"]  && vars.recentSessionEventSplit == "tut-staminastart" ||
            settings["tut-enteritems"]    && vars.recentSessionEventSplit == "tut-enteritems" ||
            settings["tut-pitonend"]      && vars.recentSessionEventSplit == "tut-pitonend" ||
            settings["tut-rebarstart"]    && vars.recentSessionEventSplit == "tut-rebarstart" ||
            settings["tut-win"]           && vars.recentSessionEventSplit == "tut-win"
        ) 
        {vars.SplitCooldownTimer.Restart();return true;}
    }

    //Full Game Region Autosplits
    if ((settings["RegionSplit"]) && (current.regionName != old.regionName) && (old.regionName != "null")) {vars.SplitCooldownTimer.Restart();return true;}
    
    //Full Game Subregion Autosplits
    if 
    (
        settings["Finish Silos Safe Room"]              && current.subregionName    != "Safe Room"              && old.subregionName        == "Safe Room" ||
        settings["Finish Pipeworks Drainage System"]    && current.subregionName    != "Drainage System"        && old.subregionName        == "Drainage System" ||
        settings["Finish Intelude: Lockdown"]           && current.regionName       == "pipeworks"              && old.levelName            == "M1_Campaign_Transition_Silo_To_Pipeworks_01" && current.levelName != "M1_Campaign_Transition_Silo_To_Pipeworks_01" ||
        settings["Finish Intelude: Ascent"]             && current.subregionName    != "Service Shaft"          && old.subregionName        == "Service Shaft" && old.levelName == "M3_Campaign_Transition_Pipeworks_To_Habitation_01" ||
        settings["Finish Habitation Safe Area"]         && current.subregionName    != "Safe Area"              && old.subregionName        == "Safe Area" || 
        settings["Finish Habitation Service Shaft"]     && old.subregionName        != "Haunted Pier Entrance"  && current.subregionName    == "Haunted Pier Entrance" || 
        settings["Finish Haunted Pier"]                 && current.subregionName    != "Haunted Pier"           && old.subregionName        == "Haunted Pier" ||
        settings["Finish Delta Labs Lobby"]             && current.subregionName    != "Delta Labs Lobby"       && old.subregionName        == "Delta Labs Lobby" ||
        settings["Finish Delta Labs"]                   && current.subregionName    != "Delta Labs"             && old.subregionName        == "Delta Labs" 
    ) 
    {vars.SplitCooldownTimer.Restart();return true;}
}

isLoading
{
    return true;
}

gameTime 
{
    return TimeSpan.FromSeconds(current.IGT);
}  

reset
{
    return settings["AutoReset"] && current.IGT < old.IGT;
}

onReset
{
    current.subregionName = "Deep Storage";
}
