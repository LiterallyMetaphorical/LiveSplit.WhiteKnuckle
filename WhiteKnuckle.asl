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

    #region debugging
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

	// creates text components for variable information
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
	#endregion

    #region setting creation
    //Parent 0
    settings.Add("AutoReset", false, "Automatically reset timer after Restarting run");
    //Parent 1
    settings.Add("Autosplit Options", true, "Autosplit Options - SELECT ONLY ONE");
    //Child 1 to Parent 1
    settings.Add("RegionSplit", true, "Split on Region change", "Autosplit Options");
    settings.Add("SubregionSplit", false, "Split on Subregion change", "Autosplit Options");
    settings.Add("LevelSplit", false, "Split on Level change", "Autosplit Options");
    //Parent 2
	settings.Add("Variable Information", true, "Variable Information");
    //Child 1 to Parent 2
    settings.Add("Player Info", true, "Player Info", "Variable Information");
    settings.Add("playerAscent", true, "playerAscent", "Player Info");
    settings.Add("ascentRate", true, "ascentRate", "Player Info");
    settings.Add("IGT", false, "IGT Display", "Player Info");
    settings.Add("splitMethod", false, "Autosplit Method Display", "Player Info");
    //Child 2 to Parent 2
    settings.Add("Level Info", true, "Level Info", "Variable Information");
    settings.Add("regionName", true, "regionName", "Level Info");
    settings.Add("subregionName", false, "subregionName", "Level Info");
    settings.Add("levelName", true, "levelName", "Level Info");
    //Child 3 to Parent 2
    settings.Add("Unity Scene Info", false, "Unity Scene Info", "Variable Information");
    settings.Add("Unity Scene Loading", false, "Unity Scene Loading", "Unity Scene Info");
    settings.Add("Loading Scene Name", false, "Loading Scene Name", "Unity Scene Info");
    settings.Add("Active Scene Name", false, "Active Scene Name", "Unity Scene Info");
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
    if (settings["SubregionSplit"]) {vars.currentAutosplitMethod = "Subregion Change";}
    if (settings["LevelSplit"]) {vars.currentAutosplitMethod = "Level Change";}

    //Setting up pretty versions of Peak Ascent and Ascent Rate
    current.playerAscentPretty = current.playerAscent.ToString().Substring(0, current.playerAscent.ToString().Length - 5);
    current.ascentRatePretty = current.ascentRate.ToString().Substring(0, current.ascentRate.ToString().Length - 4);

    //Get the current active scene's name and set it to `current.activeScene` - sometimes, it is null, so fallback to old value
    current.activeScene = vars.Helper.Scenes.Active.Name ?? current.activeScene;

    //Usually the scene that's loading, a bit jank in this version of asl-help
    current.loadingScene = vars.Helper.Scenes.Loaded[0].Name ?? current.loadingScene;

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
    if(settings["Unity Scene Loading"]){vars.SetTextComponent("Scene Loading?",vars.SceneLoading.ToString());}
    if(settings["Loading Scene Name"]){vars.SetTextComponent("LScene Name: ",current.loadingScene.ToString());}
    if(settings["Active Scene Name"]){vars.SetTextComponent("AScene Name: ",current.activeScene.ToString());}
}

onStart
{
    vars.Log("activeScene: " + current.activeScene);
    vars.Log("loadingScene: " + current.loadingScene);
}

start
{
    return current.IGT > 0 && current.IGT <= 2;
}

split
{
    if 
    (
        settings["RegionSplit"] && current.regionName != old.regionName && old.regionName != "null" ||
        settings["SubregionSplit"] && current.subregionName != old.subregionName && old.subregionName != "null" && current.subregionName != "Safe Room"||
        settings["LevelSplit"] && current.levelName != old.levelName && old.levelName != "null"
    ) 
    {return true;}
}

isLoading
{
}

gameTime 
{
    return TimeSpan.FromSeconds(current.IGT);
}  

reset
{
    return settings["AutoReset"] && current.IGT < old.IGT;
}