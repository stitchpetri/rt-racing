Config = {}


Config.Debug = true

Config.TestCourse = {
  id    = 1,
  name  = "RTR: Hanging Dog Test",
  mode  = "time_trial",
  radius = 5.0,

  start  = vector3(-2289.33, 659.0, 118.0),
  finish = vector3(-2249.33, 635.0, 118.0),
}


Config.Anchors = {
  {
    id = "trec_race",
    label = "TREC Race Track",
    position = vector3(4393.52, -2950.3, 49.18),
    radius = 6.0, -- how close needed to show prompt
    options = {
      type="course", id=2, label="Race Track - 1 lap"},

  }
  
}


Config.Courses = {
  [1] = {
    id    = 1,
    name  = "RTR: Hanging Dog Test",
    mode  = "time_trial",
    radius = 5.0,
    start  = vector3(-2289.33, 659.0, 118.0),
    finish = vector3(-2249.33, 635.0, 118.0),
    checkpoints = {}
  },
  [2] = {
    id = 2,
    name = "RTR: TREC Race Track",
    mode = "time_trial",
    radius = 15.0,
    start = vector3(4419.17, -3100.08, 46.67),
    finish = vector3(4426.51, -3152.53, 46.68),
    checkpoints = {vector3(4420.51, -3132.53, 46.68)},
    startLine = {
            type   = 4,        -- MarkerTypeCheckeredFlagRect
            length = 14.0,     -- (X scale)
            width  = 3.0,      --  (Y scale)
            height = 0.4,      -- (Z scale)
            color  = {r=255,g=255,b=255,a=180},
            zOff   = -0.95    
            }
  }
}
