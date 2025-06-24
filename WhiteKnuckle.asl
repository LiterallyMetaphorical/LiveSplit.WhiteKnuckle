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
    //Initializing Scene Loading for load removal & text component later
    vars.SceneLoading = "";
    //Setting up variable to show current autosplit method for use in text component later on
    vars.currentAutosplitMethod = "";
    //creating stopwatch to prevent very fast multi-splits
    vars.SplitCooldownTimer = new Stopwatch();

    vars.Watch = (Action<IDictionary<string, object>, IDictionary<string, object>, string>)((oldLookup, currentLookup, key) =>
    {
        // here we see a wild typescript dev attempting C#... oh, the humanity...
        var currentValue = currentLookup.ContainsKey(key) ? (currentLookup[key] ?? "(null)") : null;
        var oldValue = oldLookup.ContainsKey(key) ? (oldLookup[key] ?? "(null)") : null;
        // print if there's a change
        if (oldValue != null && currentValue != null && !oldValue.Equals(currentValue)) {vars.Log(key + ": " + oldValue + " -> " + currentValue);}
        // first iteration, print starting values
        if (oldValue == null && currentValue != null) {vars.Log(key + ": " + currentValue);}
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
    {"textDisplay", true, "Text Options", null},
    {"removeTexts", true, "Remove all texts on exit", "textDisplay"},
	{"AutoReset", true, "Automatically reset timer after Restarting run", null},
	{"AutosplitOptions", true, "Autosplit Options", null},
		{"RegionSplit", true, "Split on every Region change", "AutosplitOptions"},
        {"SubregionSplits", false, "Split on specific Subregions - EXPERIMENTAL", "AutosplitOptions"},
            {"Finish Silos Safe Room", false, "Finish Silos Safe Room", "SubregionSplits"},
            {"Finish Pipeworks Drainage System", false, "Finish Pipeworks Drainage System", "SubregionSplits"},
            {"Finish Interlude I", false, "Finish Interlude I", "SubregionSplits"},
            {"Finish Elevator", false, "Finish Elevator", "SubregionSplits"},
            {"Finish Habitation Safe Area", false, "Finish Habitation Safe Area", "SubregionSplits"},
            {"Finish Habitation Service Shaft", false, "Finish Habitation Service Shaft", "SubregionSplits"},
            {"Finish Haunted Pier", false, "Finish Haunted Pier", "SubregionSplits"},
            {"Finish Delta Labs Lobby", false, "Finish Delta Labs Lobby", "SubregionSplits"},
            {"Finish Delta Labs", false, "Finish Delta Labs", "SubregionSplits"},
	{"VariableInformation", true, "Variable Information", null},
		{"PlayerInfo", true, "Player Info", "VariableInformation"},
			{"Run Peak Ascent", true, "Player Peak Ascent of this run", "PlayerInfo"},
			{"Ascent Rate", true, "Ascent Rate of this run", "PlayerInfo"},
			{"IGT", false, "IGT Display", "PlayerInfo"},
			{"splitMethod", false, "Autosplit Method Display", "PlayerInfo"},
		{"LevelInfo", true, "Level Info", "VariableInformation"},
			{"Region Name", true, "Current Regigon Name", "LevelInfo"},
			{"Subregion Name", false, "Current Subregion Name", "LevelInfo"},
			{"Level Name", true, "Current Level Name", "LevelInfo"},
		{"UnitySceneInfo", false, "Unity Scene Info", "VariableInformation"},
			{"UnitySceneLoading", false, "Unity Scene Loading", "UnitySceneInfo"},
			{"LoadingSceneName", false, "Loading Scene Name", "UnitySceneInfo"},
			{"ActiveSceneName", false, "Active Scene Name", "UnitySceneInfo"},
	};
	vars.Helper.Settings.Create(_settings);
    #endregion
}

init
{
    //helps clear some errors when scene is null
    current.Scene = "";
    current.activeScene = "";
    current.loadingScene = "";
    current.levelName = "";
    current.regionName = "";
    current.subregionName = "";
    current.playerAscent = 0;
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

        //error handling
    if(current.subregionName == null){current.subregionName = "null";}
    if(current.regionName == null){current.regionName = "null";}


    //Updating Current Autosplit Method var for use in text component
    if (settings["RegionSplit"]) {vars.currentAutosplitMethod = "Region Change";}

    //Setting up pretty versions of Peak Ascent and Ascent Rate, starting with Peak Ascent
    if(current.playerAscent > 0 && current.playerAscent <= 100){current.playerAscentPretty = current.playerAscent.ToString().Substring(0, current.playerAscent.ToString().Length - 4);} //vars.Log("Over 0m & equal or under 100m, Removing 4 Characters from end of string");
    if(current.playerAscent > 100 && current.playerAscent <= 1000){current.playerAscentPretty = current.playerAscent.ToString().Substring(0, current.playerAscent.ToString().Length - 3);}//vars.Log("Over 100m & equal or under 1,000m, Removing 3 Characters from end of string");
    if(current.playerAscent > 1000 && current.playerAscent <= 10000){current.playerAscentPretty = current.playerAscent.ToString().Substring(0, current.playerAscent.ToString().Length - 1);}//vars.Log("Over 1000m & equal or under 10,000m, Removing 1 Character from end of string");
    if(current.playerAscent > 10000 && current.playerAscent <= 100000){current.playerAscentPretty = current.playerAscent;}//vars.Log("Over 10,000m & equal or under 100,000m, no longer removing characters from end of string");
    //Now for ascentRate
    if(current.ascentRate > 0 && current.ascentRate <= 1){current.ascentRatePretty = current.ascentRate.ToString().Substring(0, current.playerAscent.ToString().Length - 3);}//vars.Log("Over 0m/s & equal or under 1m/s, Removing 2 Characters from end of string");
    if(current.ascentRate > 1 && current.ascentRate <= 9.99){current.ascentRatePretty = current.ascentRate.ToString().Substring(0, current.playerAscent.ToString().Length - 4);}//vars.Log("Over 1m/s & equal or under 9.9m/s, Removing 4 Characters from end of string");
    if(current.ascentRate >= 10 && current.ascentRate <= 100){current.ascentRatePretty = current.ascentRate.ToString().Substring(0, current.playerAscent.ToString().Length - 3);}//vars.Log("Equal or over 10m/s & equal or under 100m/s, Removing 3 Characters from end of string");

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

    //Setting up for load removal & text display of load removal stuff
    if(old.loadingScene != current.loadingScene){vars.SceneLoading = "Loading";}
    if(old.activeScene != current.activeScene){vars.SceneLoading = "Not Loading";}

    //More text component stuff - checking for setting and then generating the text. No need for .ToString since we do that previously
    vars.SetTextIfEnabled("splitMethod",vars.currentAutosplitMethod);
    vars.SetTextIfEnabled("Region Name",current.regionName);
    vars.SetTextIfEnabled("Subregion Name",current.subregionName);
    vars.SetTextIfEnabled("Level Name",current.levelName);
    vars.SetTextIfEnabled("IGT",current.IGT);
    vars.SetTextIfEnabled("Run Peak Ascent",current.playerAscentPretty + " Meters");
    vars.SetTextIfEnabled("Ascent Rate",current.ascentRatePretty + " M/s");
    vars.SetTextIfEnabled("UnitySceneLoading",vars.SceneLoading);
    vars.SetTextIfEnabled("LoadingSceneName",current.loadingScene);
    vars.SetTextIfEnabled("ActiveSceneName",current.activeScene);
}

onStart
{
    vars.Log("activeScene: " + current.activeScene);
    vars.Log("loadingScene: " + current.loadingScene);
}

start
{
    if((current.IGT > 0 && current.IGT <= 2) && (current.activeScene != "Main-Menu"))
    {
    vars.SplitCooldownTimer.Restart();
    return true;
    }
}

split
{
    if(vars.SplitCooldownTimer.Elapsed.TotalSeconds < 2) {return false;}

    //Full Game Region Autosplits
    if ((settings["RegionSplit"]) && (current.regionName != old.regionName) && (old.regionName != "null")) {vars.SplitCooldownTimer.Restart();return true;}
    
    //Full Game Subregion Autosplits
    if 
    (
        settings["Finish Silos Safe Room"] && current.subregionName != "Safe Room" && old.subregionName == "Safe Room" ||
        settings["Finish Pipeworks Drainage System"] && current.subregionName != "Drainage System" && old.subregionName == "Drainage System" ||
        settings["Finish Interlude I"] && current.regionName == "pipeworks" && old.levelName == "M1_Campaign_Transition_Silo_To_Pipeworks_01" && current.levelName != "M1_Campaign_Transition_Silo_To_Pipeworks_01" ||
        settings["Finish Elevator"] && current.subregionName != "Service Shaft" && old.subregionName == "Service Shaft" && old.levelName == "M3_Campaign_Transition_Pipeworks_To_Habitation_01" ||
        settings["Finish Habitation Safe Area"] && current.subregionName != "Safe Area" && old.subregionName == "Safe Area" || //needs some adjusting, maybe check height?
        settings["Finish Habitation Service Shaft"] && current.subregionName == "Service Shaft Ending" && current.subregionName == "Haunted Pier Entrance" || // modify first condition just to make it not weird
        settings["Finish Haunted Pier"] && current.subregionName != "Haunted Pier" && old.subregionName == "Haunted Pier" ||
        settings["Finish Delta Labs Lobby"] && current.subregionName != "Delta Labs Lobby" && old.subregionName == "Delta Labs Lobby" ||
        settings["Finish Delta Labs"] && current.subregionName != "Delta Labs" && old.subregionName == "Delta Labs" 
    ) 
    {vars.SplitCooldownTimer.Restart();return true;}
    
    //Tutorial Autosplits
    if 
    (
        (current.levelName == "Training_Level_01" && current.playerAscent > 8 && current.playerAscent < 9)  || // Mantling & Momentum
        (current.levelName == "Training_Level_01" && current.playerAscent > 24 && current.playerAscent < 25)  || // Climbing & Stamina
        (current.levelName == "Training_Level_01" && current.playerAscent > 50.5 && current.playerAscent < 51.1)  || // Pitons & Inventory
        (current.levelName == "Training_Level_01" && current.playerAscent > 67   && current.playerAscent < 68)   // Rebar
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
