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
    checkpoints = {vector3(4420.51, -3132.53, 46.68)}
  }
}
