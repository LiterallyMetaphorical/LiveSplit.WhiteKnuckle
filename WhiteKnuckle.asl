state("White Knuckle") { }

startup
{
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

	//creates text components for variable information
	vars.SetTextComponent = (Action<string, string>)((id, text) =>
	{
	var textSettings = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent").Select(x => x.GetType().GetProperty("Settings").GetValue(x, null));
	var textSetting = textSettings.FirstOrDefault(x => (x.GetType().GetProperty("Text1").GetValue(x, null) as string) == id);
	if (textSetting == null)
	    {
            var textComponentAssembly = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
            var textComponent = Activator.CreateInstance(textComponentAssembly.GetType("LiveSplit.UI.Components.TextComponent"), timer);
            timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent("LiveSplit.Text.dll", textComponent as LiveSplit.UI.Components.IComponent));
            textSetting = textComponent.GetType().GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public).GetValue(textComponent, null);
            textSetting.GetType().GetProperty("Text1").SetValue(textSetting, id);
	    }
	textSetting.GetType().GetProperty("Text2").SetValue(textSetting, text);
    });

    #region setting creation
	//Autosplitter Settings Creation
	dynamic[,] _settings =
	{
	{"AutoReset", false, "Automatically reset timer after Restarting run", null},
	{"AutosplitOptions", true, "Autosplit Options - SELECT ONLY ONE", null},
		{"RegionSplit", true, "Split on every Region change", "AutosplitOptions"},
	{"VariableInformation", true, "Variable Information", null},
		{"PlayerInfo", true, "Player Info", "VariableInformation"},
			{"playerAscent", true, "playerAscent", "PlayerInfo"},
			{"ascentRate", true, "ascentRate", "PlayerInfo"},
			{"IGT", false, "IGT Display", "PlayerInfo"},
			{"splitMethod", false, "Autosplit Method Display", "PlayerInfo"},
		{"LevelInfo", true, "Level Info", "VariableInformation"},
			{"regionName", true, "regionName", "LevelInfo"},
			{"subregionName", false, "subregionName", "LevelInfo"},
			{"levelName", true, "levelName", "LevelInfo"},
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

    //Starting the timer for the splitter cooldown
    vars.SplitCooldownTimer.Start();

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
}

update
{
    vars.Watch(old, current, "IGT");
    vars.Watch(old, current, "playerAscent");
    vars.Watch(old, current, "ascentRate");
    vars.Watch(old, current, "levelName");
    vars.Watch(old, current, "regionName");
    vars.Watch(old, current, "subregionName");

    //Trying to handle errors, idk why but subregion seems to be particularly bad
    if (current.subregionName == null) {current.subregionName = "null";}

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

    //Prints various information based on settings selections
    if(settings["splitMethod"]){vars.SetTextComponent("Split Method:",vars.currentAutosplitMethod.ToString());}
    if(settings["levelName"]){vars.SetTextComponent("Level: ",current.levelName.ToString());}
    if(settings["regionName"]){vars.SetTextComponent("Region: ",current.regionName.ToString());}
    if(settings["subregionName"]){vars.SetTextComponent("Subregion: ",current.subregionName.ToString());}
    if(settings["IGT"]){vars.SetTextComponent("IGT: ",current.IGT.ToString());}
    if(settings["playerAscent"]){vars.SetTextComponent("Run Peak Ascent: ",current.playerAscentPretty.ToString() + " Meters");}
    if(settings["ascentRate"]){vars.SetTextComponent("Ascent Rate: ",current.ascentRatePretty.ToString() + " M/s");}
    if(settings["UnitySceneLoading"]){vars.SetTextComponent("Scene Loading?",vars.SceneLoading.ToString());}
    if(settings["LoadingSceneName"]){vars.SetTextComponent("LScene Name: ",current.loadingScene.ToString());}
    if(settings["ActiveSceneName"]){vars.SetTextComponent("AScene Name: ",current.activeScene.ToString());}
}

onStart
{
    vars.Log("activeScene: " + current.activeScene);
    vars.Log("loadingScene: " + current.loadingScene);
}

start
{
    if(current.IGT > 0 && current.IGT <= 2)
    {
    vars.SplitCooldownTimer.Restart();
    return true;
    }
}

split
{
    if(vars.SplitCooldownTimer.Elapsed.TotalSeconds < 5) {return false;}

    if 
    (
        settings["RegionSplit"] && current.regionName != old.regionName && old.regionName != "null"
    )
    {
        vars.SplitCooldownTimer.Restart();
        return true;
    }
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
