return {
  operations = {
    { key = 'south_ls_dead_drop', label = 'Recover a dead drop', kind = 'stash_recovery', district = 'south_ls', coords = vec3(124.2, -1937.6, 20.8), minNetwork = 0, payout = { min = 350, max = 650 }, heat = 2, network = 1, intel = 1 },
    { key = 'vespucci_recon', label = 'Photograph a meeting point', kind = 'recon', district = 'vespucci', coords = vec3(-1165.7, -1516.3, 4.4), minNetwork = 5, payout = { min = 500, max = 850 }, heat = 1, network = 1, intel = 2 },
    { key = 'east_ls_courier', label = 'Move a sealed package', kind = 'courier', district = 'east_ls', coords = vec3(916.1, -1702.4, 51.2), minNetwork = 10, payout = { min = 700, max = 1100 }, heat = 3, network = 2, intel = 1 },
    { key = 'county_trace', label = 'Trace an abandoned vehicle', kind = 'vehicle_trace', district = 'county', coords = vec3(1691.9, 3595.3, 35.6), minNetwork = 15, payout = { min = 900, max = 1400 }, heat = 2, network = 2, intel = 2 }
  },
  completionDistance = 8.0,
  operationCooldownMinutes = 20
}
