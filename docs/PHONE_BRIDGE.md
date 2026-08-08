# LOTB City App / Phone Bridge

LOTB does not hard-code itself to one paid phone resource. The `lotb_cityapp` resource provides a stable LOTB-owned backend and a fallback `/cityapp` interface.

## Client integration

A phone app or button can open the LOTB fallback interface with either:

```lua
TriggerEvent('lotb_cityapp:open')
```

or:

```lua
exports.lotb_cityapp:OpenCityApp()
```

## Server integration

A phone adapter can request the same normalized home data used by the fallback UI:

```lua
local feed = exports.lotb_cityapp:GetHomeFeed(source)
```

The returned table contains:

- `district`
- `districtSummary` — qualitative, not raw hidden district scores
- `notices`
- `archive`
- `contracts` for the current character
- `properties` the character owns/can access
- `businesses` the character owns
- `insurance` claim summaries

## Design rule

Keep vendor-specific phone code in a small adapter resource. Do not move City Memory, contracts, properties, insurance, rumors, dispatch, or other LOTB authority into a phone script. That way the phone can be changed later without rewriting the city.

## Emergency services

The fallback City app submits 911/311 through the LOTB dispatch server event. A phone adapter should call the same server-side dispatch path rather than creating a second emergency-call database.

## Security

Do not trust phone NUI/client input for money, property, insurance decisions, evidence, rewards or progression. The phone should display data and request actions; the LOTB server resources should remain authoritative.
