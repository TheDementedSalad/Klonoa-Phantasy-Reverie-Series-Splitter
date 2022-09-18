// Klonoa Phantasy Reverie Series Autosplitter Version 1.1.0 (24/08/2022)
// Supports Door to Phantomile & Lunatea's Veil
// Supports IGT
// Splits can be obtained from -
// Script and Remodification by TheDementedSalad, NickPRGreen & Ero
// Special thanks to:
// Ero - Creation of the vars.helper which made this possible
// bmn - Providing a starting point for which classes to check and teaching me some things
// Nikoheart & baugliore - Teaching me the basics and spending hours in calls with me to help

state("Klonoa")
{}

startup
{
	vars.Log = (Action<object>)(output => print("[Klonoa] " + output));

	var bytes = File.ReadAllBytes(@"Components\LiveSplit.ASLHelper.bin");
	var type = Assembly.Load(bytes).GetType("ASLHelper.Unity");
	vars.Helper = Activator.CreateInstance(type, timer, /* settings, */ this);
	// vars.Helper.LoadSceneManager = true;
}

onStart 
{
	vars.SplitSkip = new List<int>()
    {-1,1,4,5,9,10,15,20};
}

onSplit
{}

onReset
{}

init
{
	
	vars.Helper.TryOnLoad = (Func<dynamic, bool>)(mono =>
	{
		
		var gg = mono.GetClass("GameGlobal", 1);
		var ns = gg.Make<int>("instance", "nowScene");
		vars.Helper["Game"] = gg.Make<int>("instance", "nowScene");
		ns.Update(game);

		switch ((int)ns.Current){
			
			default: return false;
			
			case 1:
			{
			 // Door to Phantomile classes
				var glb = mono.GetClass("nsPFW.Global", 1); 												// depth=1 so we have access to SingletonMonoBehaviour<Global>.instance
				var ct = mono.GetClass("nsPFW.nsTimeAttack.CTimer");										// nsPFW.nsTimeAttack.CTimer
				var cf = mono.GetClass("nsPFW.CField", 1);
				var tvi = mono.GetClass("nsPFW.tVisionInfo");
				var tr = mono.GetClass(0x20004C2); 															// CField.tResult
				
				// Door to Phantomile info 
				vars.Helper["Time"] = glb.Make<float>("instance", "m_TotalTimer", ct["m_Seconds"]);			// official game time in secs (float)
				vars.Helper["VisionID"] = cf.Make<ushort>("instance", "m_VisionInfo", tvi["m_VisionID"]);	// ID of currrent vision
				vars.Helper["StageCleared"] = cf.Make<bool>("instance", "m_Result", tr["m_IsCleared"]);		// Checks whether the stage has been completed or not
				return true;
			}
			case 2:
			{
			  // Lunatea's Veil classes
				var gc = mono.GetClass("App.Klonoa2.Game");
				var gd = mono.GetClass("GAMEDATA");
				var hgd = mono.GetClass("hGAMEDATA");
				var gw = mono.GetClass("GAME_WORK");
				
				// Lunatea's Veil info
				vars.Helper["visionNumber"] = gc.Make<int>("clear_event_no");								// current vision number
				vars.Helper["IGT"] = gc.Make<int>("gamdat", gd["clearTimeCount"]);							// official game time in frames
				vars.Helper["roomNumber"] = gc.Make<int>("GameGbl", gw["vision"]);								// number representing current room
				vars.Helper["non_pause_flag"] = gc.Make<int>("GameGbl", gw["non_pause_flag"]); 				// when IGT has paused due to non-pause
				vars.Helper["clear"] = gc.Make<ulong>("gamdat", gd["clear"]);								// a bit-array that updates when any stage is cleared for the first time
				vars.Helper["areaTime"] = gc.Make<int>("GameData", hgd["areaTime"]);						// time spent in current area (including pauses) in frames
				return true;
			}
		}
	});

	vars.Helper.Load();
}

update
{
	if (!vars.Helper.Update())
		return false;

	vars.Helper.MapWatchersToCurrent(current);
}

start
{
	if(current.Game == 1)
		return current.Time > 0f && old.Time == 0f && current.VisionID == 1;
	
	else return current.IGT != old.IGT && current.roomNumber == 256;
}

split
{	
	if(current.Game == 1){
		return current.StageCleared && !old.StageCleared;
	}
	
	if(current.Game == 2){
		var visionNumber = vars.Helper["visionNumber"];
		var clear = vars.Helper["clear"];
		
		//split when a level ends and transitions to the autosave screen
		if (visionNumber.Changed && clear.Changed) {
			if(vars.SplitSkip.Contains(old.visionNumber)) return false;
				else {
					return true;
					vars.SplitSkip.Add(old.visionNumber);
				}
			}
			
	   //final split when final hit lands on the King of Sorrow - split will only occur after at least 25 seconds have passed
	   if ((vars.Helper["areaTime"].Current > 1500) && (vars.Helper["roomNumber"].Current == 6912) && (vars.Helper["non_pause_flag"].Current == 1)) {
			return true;
	   }
	}
}

gameTime
{
	if(current.Game == 1)
		return TimeSpan.FromSeconds(current.Time);
	
	if(current.Game == 2)
		return TimeSpan.FromSeconds(current.IGT / 60f);
}

isLoading
{
	return true;
}

reset
{
	if(current.Game == 1)
		return current.Time == 0 && current.VisionID == 1;
	
	if(current.Game == 2)
		return current.roomNumber == 7682 && old.roomNumber == 7936;
}


exit
{
	vars.Helper.Dispose();
}

shutdown
{
	vars.Helper.Dispose();
}
