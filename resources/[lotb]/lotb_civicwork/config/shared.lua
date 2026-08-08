return {
  sites = {
    { key='south_cleanup', district='south_ls', kind='cleanup', label='Neighborhood cleanup', coords=vec3(215.6,-1638.7,29.8), pay={min=450,max=700}, effect={instability=-2,community_pride=2} },
    { key='east_repair', district='east_ls', kind='repair', label='Community repair call', coords=vec3(948.6,-2103.8,30.6), pay={min=550,max=850}, effect={prosperity=1,community_pride=2} },
    { key='downtown_logistics', district='downtown', kind='logistics', label='Downtown supply delivery', coords=vec3(120.4,-1058.9,29.2), pay={min=500,max=800}, effect={prosperity=2} },
    { key='vespucci_cleanup', district='vespucci', kind='cleanup', label='Beach district cleanup', coords=vec3(-1198.8,-1489.0,4.4), pay={min=400,max=650}, effect={community_pride=2,instability=-1} },
    { key='county_infra', district='county', kind='inspection', label='County infrastructure inspection', coords=vec3(1959.4,3740.7,32.3), pay={min=650,max=950}, effect={prosperity=1,trust=1} },
    { key='airport_logistics', district='airport', kind='logistics', label='Airport freight support', coords=vec3(-1037.4,-2737.8,20.2), pay={min=700,max=1000}, effect={prosperity=2,trust=1} }
  },
  completionDistance=8.0,
  cooldownMinutes=12
}
