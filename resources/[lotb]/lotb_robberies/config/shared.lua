return {
  targets = {
    { key = 'davis_market', label = 'Davis Market Back Office', district = 'south_ls', coords = vec3(24.4, -1347.3, 29.5), minNetwork = 5, minPolice = 1, cooldownMinutes = 50, payout = { min = 900, max = 1600 } },
    { key = 'vespucci_office', label = 'Vespucci Cash Office', district = 'vespucci', coords = vec3(-1221.2, -916.4, 11.3), minNetwork = 10, minPolice = 1, cooldownMinutes = 60, payout = { min = 1300, max = 2200 } },
    { key = 'east_ls_warehouse', label = 'East LS Warehouse Cage', district = 'east_ls', coords = vec3(948.1, -1697.5, 30.1), minNetwork = 20, minPolice = 2, cooldownMinutes = 90, payout = { min = 2200, max = 3800 } }
  },
  startDistance = 6.0,
  stageDistance = 10.0,
  stages = {
    { key = 'access', label = 'Defeating access control...', duration = 9000 },
    { key = 'search', label = 'Searching for the secured cash...', duration = 12000 },
    { key = 'exit', label = 'Clearing the scene...', duration = 6000 }
  }
}
