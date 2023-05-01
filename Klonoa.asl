/* Klonoa Phantasy Reverie Series Autosplitter Version 1.2.0 (01/05/2023)
Supports Door to Phantomile & Lunatea's Veil (Any%/All Visions/100%)
Supports IGT, including adding the additional time from Chamber of Fun/Horror in KPR2
Splits can be obtained from https://www.speedrun.com/klonoaprs/resources
Script and Remodification by TheDementedSalad, NickPRGreen & Ero
Special thanks to:
Ero - Creation of the vars.helper which made this possible
bmn - Providing a starting point for which classes to check and teaching me some things
Nikoheart & baugliore - Teaching me the basics and spending hours in calls with me to help
NeilLegend - Testing and suggestions for KPRS2 All Visions/100% support */

state("Klonoa") {	
}

startup {
	vars.Log = (Action<object>)(output => print("[Klonoa] " + output));
	var bytes = File.ReadAllBytes(@"Components\LiveSplit.ASLHelper.bin");
	var type = Assembly.Load(bytes).GetType("ASLHelper.Unity");
	vars.Helper = Activator.CreateInstance(type, timer, this);
}

onStart {
	vars.SplitSkip = new List<int>() {-1,1,4,5,9,10,15,20,29}; 									// List of cutscene only Visions to be skipped in KPR2
	vars.Chambers = 0;														// Stores the additional time from the two Chamber bonus levels in KPR2 All Visions/100%
	vars.excessMS = 0;														// Stores any excess milliseconds over the last whole second to correctly time KPR2 All Visions/100%
}

init {
	vars.Helper.TryOnLoad = (Func<dynamic, bool>)(mono => {
		var gg = mono.GetClass("GameGlobal", 1);
		var ns = gg.Make<int>("instance", "nowScene");
		vars.Helper["Game"] = gg.Make<int>("instance", "nowScene");
		ns.Update(game);
		switch ((int)ns.Current) {			
			default: return false;		
			case 1: {
			 	// Door to Phantomile classes
				var glb = mono.GetClass("nsPFW.Global", 1); 								// depth=1 so we have access to SingletonMonoBehaviour<Global>.instance
				var ct = mono.GetClass("nsPFW.nsTimeAttack.CTimer");							// nsPFW.nsTimeAttack.CTimer
				var cf = mono.GetClass("nsPFW.CField", 1);
				var tvi = mono.GetClass("nsPFW.tVisionInfo");
				var tr = mono.GetClass(0x20004C2); 									// CField.tResult				
				
				// Door to Phantomile info 
				vars.Helper["Time"] = glb.Make<float>("instance", "m_TotalTimer", ct["m_Seconds"]);			// official game time in secs (float)
				vars.Helper["VisionID"] = cf.Make<ushort>("instance", "m_VisionInfo", tvi["m_VisionID"]);		// ID of currrent vision
				vars.Helper["StageCleared"] = cf.Make<bool>("instance", "m_Result", tr["m_IsCleared"]);			// Checks whether the stage has been completed or not
				return true;
			}
			case 2: {
			  	// Lunatea's Veil classes
				var gc = mono.GetClass("App.Klonoa2.Game");
				var gd = mono.GetClass("GAMEDATA");
				var hgd = mono.GetClass("hGAMEDATA");
				var gw = mono.GetClass("GAME_WORK");
						
				// Lunatea's Veil info
				vars.Helper["visionNumber"] = gc.Make<int>("clear_event_no");						// current vision number
				vars.Helper["IGT"] = gc.Make<int>("gamdat", gd["clearTimeCount"]);					// official game time in frames
				vars.Helper["roomNumber"] = gc.Make<int>("GameGbl", gw["vision"]);					// number representing current room
				vars.Helper["non_pause_flag"] = gc.Make<int>("GameGbl", gw["non_pause_flag"]); 				// when IGT has paused due to non-pause
				vars.Helper["clear"] = gc.Make<ulong>("gamdat", gd["clear"]);						// a bit-array that updates when any stage is cleared for the first time
				vars.Helper["areaTime"] = gc.Make<int>("GameData", hgd["areaTime"]);					// time spent in current area (including pauses) in frames
				vars.Helper["playdemo_flag"] = gc.Make<int>("GameGbl", gw["playdemo_flag"]);				// when the demo is playing after being idle on the title screen
				vars.Helper["time_attack"] = gc.Make<int>("GameGbl", gw["time_atack_cnt"]);				// timer used for Chamber of Fun/Horror & House of Horrors
				return true;
			}
		}
	});
	vars.Helper.Load();
}

update {
	if (!vars.Helper.Update()) return false;
	vars.Helper.MapWatchersToCurrent(current);
	var playdemo_flag = vars.Helper["playdemo_flag"];
	var time_attack = vars.Helper["time_attack"];
	var visionNumber = vars.Helper["visionNumber"];
	var clear = vars.Helper["clear"];
	if (old.time_attack > 0 && current.time_attack == 0) vars.Chambers = vars.Chambers + old.time_attack;				// adds a completed Chamber's time to the Chamber Time Store
	if (visionNumber.Changed && clear.Changed && old.visionNumber == 28) vars.excessMS = current.IGT-(60*((current.IGT+30)/60));	// records the excess milliseconds once a KPR2 run has completed
}

start {
	if(current.Game == 1) return current.Time > 0f && old.Time == 0f && current.VisionID == 1;					// only start KP1 if IGT has increased from 0 and the first level is running
	if(current.Game == 2) return current.IGT != old.IGT && current.roomNumber == 256 && current.playdemo_flag == 0;			// only starts KPR2 if IGT has changed, room is the first room of Sea of Tears, and the demo isn't playing
}

split {	
	if(current.Game == 1) return current.StageCleared && !old.StageCleared;
	if(current.Game == 2){
		var visionNumber = vars.Helper["visionNumber"];
		var clear = vars.Helper["clear"];	

		if(visionNumber.Changed && clear.Changed) {
			if(vars.SplitSkip.Contains(old.visionNumber)) return false;							// do not split if the completed vision was a cutscene vision, or a vison already compeleted
			else {
				vars.SplitSkip.Add(old.visionNumber);									// add completed vision to the list of splits to skip
				return true;												// split once transitioned from vision clear to save screen (this includes the final split after defeating the King of Sorrow)
			}
		}
	}
}

gameTime {
	if(current.Game == 1) return TimeSpan.FromSeconds(current.Time);
	if(current.Game == 2) return TimeSpan.FromSeconds((current.IGT + current.time_attack + vars.Chambers - vars.excessMS) / 60f);
}

isLoading {
	return true;
}

reset {
	if(current.Game == 1) return current.Time == 0 && current.VisionID == 1;
	if(current.Game == 2) return current.roomNumber == 7682 && old.roomNumber == 7936;
}

exit {
	vars.Helper.Dispose();
}

shutdown {
	vars.Helper.Dispose();
}
