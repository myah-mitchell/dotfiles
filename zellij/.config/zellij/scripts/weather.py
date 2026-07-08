#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""One-line weather for the zjstatus bar.

Geolocates via WAN IP (ipinfo.io), fetches conditions from open-meteo, and
prints a single Nerd-Font-glyph line, e.g.:

    󰖗 64°(58°) ↑72° ↓51° 󰖎 87% 󰖝 12 󰕊 65% 󰖌 0.08"

    {icon} {temp}°({feels}°) ↑{high}° ↓{low}° 󰖎 {humidity}% 󰖝 {wind mph}
        [󰕊 {rain chance}%] [󰖌 {rain in}"] [󰜗 {snow in}"]

Icons are followed by a space — JetBrainsMono Nerd Font Propo renders the wide
MDI glyphs over the next character otherwise.

Quiet stats are dropped so only glanceworthy numbers remain:

- Feels-like only appears when it differs from the actual temp by >= FEELS_DELTA °F.
- High/low only appear when >= HILO_DELTA °F away from the current temp.
- Humidity only appears at >= MIN_HUMIDITY %.
- Wind only appears at >= MIN_WIND mph.
- Chance of rain (today's max precipitation probability) only appears at >= MIN_RAIN_CHANCE %.
- Rain/snow amounts (preceding hour) only appear when nonzero.
- Results are cached in ~/.cache/zellij-weather.json: weather for WEATHER_TTL,
  the IP geolocation for LOC_TTL. On network failure the stale line is reused,
  so the bar never flickers to an error state; once it is STALE_AFTER old the
  line gains a 󰖪 disconnected marker. zjstatus can therefore poll this script
  frequently; the API is only hit every 15 minutes.
- Location override: put "lat,lon" in ~/.config/zellij/weather-location to skip
  IP geolocation entirely (useful on VPNs, which put the WAN IP in the wrong
  city).
"""

import json
import sys
import time
import urllib.request
from pathlib import Path

CACHE_FILE = Path.home() / ".cache" / "zellij-weather.json"
LOC_OVERRIDE_FILE = Path.home() / ".config" / "zellij" / "weather-location"
WEATHER_TTL = 900    # seconds between API refreshes
LOC_TTL = 3600       # seconds between IP geolocation refreshes
STALE_AFTER = 3600   # seconds before a cached line gets the disconnected marker
FEELS_DELTA = 3      # °F difference before feels-like is shown
HILO_DELTA = 5       # °F distance from current temp before high/low are shown
MIN_HUMIDITY = 40    # % below which humidity is hidden
MIN_WIND = 5         # mph below which wind is hidden
MIN_RAIN_CHANCE = 10 # % below which chance of rain is hidden
FALLBACK = "\U000F0F2F --"  # 󰼯 weather-cloudy-alert — no data and no cache

# Material Design Icons (Nerd Font PUA plane), matching the rest of the bar.
ICON_HUMIDITY = "\U000F058E"     # 󰖎 water-percent
ICON_WIND = "\U000F059D"         # 󰖝 weather-windy
ICON_RAIN_CHANCE = "\U000F054A"  # 󰕊 umbrella
ICON_RAIN_AMT = "\U000F058C"     # 󰖌 water
ICON_SNOW_AMT = "\U000F0717"     # 󰜗 snowflake
ICON_STALE = "\U000F05AA"        # 󰖪 wifi-off

DAY_ICONS = {
    0: "\U000F0599",   # 󰖙 weather-sunny
    1: "\U000F0599",
    2: "\U000F0595",   # 󰖕 weather-partly-cloudy
}
NIGHT_ICONS = {
    0: "\U000F0594",   # 󰖔 weather-night
    1: "\U000F0594",
    2: "\U000F0F31",   # 󰼱 weather-night-partly-cloudy
}
# WMO weather codes, day/night agnostic.
CODE_ICONS = {
    3: "\U000F0590",                       # 󰖐 overcast — weather-cloudy
    45: "\U000F0591", 48: "\U000F0591",    # 󰖑 fog — weather-fog
    51: "\U000F0597", 53: "\U000F0597", 55: "\U000F0597",  # 󰖗 drizzle — weather-rainy
    56: "\U000F067F", 57: "\U000F067F",    # 󰙿 freezing drizzle — weather-snowy-rainy
    61: "\U000F0597", 80: "\U000F0597",    # 󰖗 light rain / showers — weather-rainy
    63: "\U000F0596", 65: "\U000F0596",    # 󰖖 moderate/heavy rain — weather-pouring
    81: "\U000F0596", 82: "\U000F0596",    # 󰖖 heavy showers — weather-pouring
    66: "\U000F067F", 67: "\U000F067F",    # 󰙿 freezing rain — weather-snowy-rainy
    71: "\U000F0598", 73: "\U000F0598",    # 󰖘 light/moderate snow — weather-snowy
    77: "\U000F0598", 85: "\U000F0598",    # 󰖘 snow grains / light snow showers
    75: "\U000F0F36", 86: "\U000F0F36",    # 󰼶 heavy snow — weather-snowy-heavy
    95: "\U000F0593",                      # 󰖓 thunderstorm — weather-lightning
    96: "\U000F067E", 99: "\U000F067E",    # 󰙾 thunderstorm + hail — weather-lightning-rainy
}


def fetch_json(url, timeout=8):
    req = urllib.request.Request(url, headers={"User-Agent": "zjstatus-weather"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def load_cache():
    try:
        return json.loads(CACHE_FILE.read_text())
    except (OSError, ValueError):
        return {}


def save_cache(cache):
    try:
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        CACHE_FILE.write_text(json.dumps(cache))
    except OSError:
        pass


def get_location(cache):
    """Returns (lat, lon) as strings, or None. Override file > cached IP geo > ipinfo."""
    try:
        lat, lon = LOC_OVERRIDE_FILE.read_text().strip().split(",")[:2]
        return lat.strip(), lon.strip()
    except (OSError, ValueError):
        pass

    loc = cache.get("loc", {})
    if loc.get("ts", 0) + LOC_TTL > time.time():
        return loc["lat"], loc["lon"]

    try:
        lat, lon = fetch_json("https://ipinfo.io/json")["loc"].split(",")
    except Exception:
        # Stale geolocation beats none at all.
        if "lat" in loc:
            return loc["lat"], loc["lon"]
        return None

    cache["loc"] = {"ts": time.time(), "lat": lat, "lon": lon}
    return lat, lon


def condition_icon(code, is_day):
    variants = DAY_ICONS if is_day else NIGHT_ICONS
    return variants.get(code) or CODE_ICONS.get(code, "\U000F0F2F")  # 󰼯 unknown


def render(data):
    cur = data["current"]
    daily = data["daily"]

    temp = round(cur["temperature_2m"])
    feels = round(cur["apparent_temperature"])
    high = round(daily["temperature_2m_max"][0])
    low = round(daily["temperature_2m_min"][0])
    humidity = round(cur["relative_humidity_2m"])
    wind = round(cur["wind_speed_10m"])

    parts = [
        condition_icon(cur["weather_code"], cur["is_day"] == 1),
        f"{temp}°" + (f"({feels}°)" if abs(feels - temp) >= FEELS_DELTA else ""),
    ]
    if abs(high - temp) >= HILO_DELTA:
        parts.append(f"↑{high}°")
    if abs(low - temp) >= HILO_DELTA:
        parts.append(f"↓{low}°")
    if humidity >= MIN_HUMIDITY:
        parts.append(f"{ICON_HUMIDITY} {humidity}%")
    if wind >= MIN_WIND:
        parts.append(f"{ICON_WIND} {wind}")

    rain_chance = (daily.get("precipitation_probability_max") or [0])[0] or 0
    if rain_chance >= MIN_RAIN_CHANCE:
        parts.append(f"{ICON_RAIN_CHANCE} {round(rain_chance)}%")

    rain = cur["rain"] + cur["showers"]
    if rain > 0:
        parts.append(f'{ICON_RAIN_AMT} {rain:.2f}"')
    if cur["snowfall"] > 0:
        parts.append(f'{ICON_SNOW_AMT} {cur["snowfall"]:.1f}"')

    return " ".join(parts)


def emit_cached(cache):
    """Print the last good line, marked disconnected once it's an hour old."""
    if "line" not in cache:
        print(f" {FALLBACK} ")
        return
    marker = f"{ICON_STALE} " if time.time() - cache["ts"] >= STALE_AFTER else ""
    print(f" {marker}{cache['line']} ")


def main():
    cache = load_cache()

    if cache.get("ts", 0) + WEATHER_TTL > time.time() and "line" in cache:
        print(f" {cache['line']} ")
        return

    loc = get_location(cache)
    if loc is None:
        emit_cached(cache)
        return

    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={loc[0]}&longitude={loc[1]}"
        "&current=temperature_2m,apparent_temperature,relative_humidity_2m,"
        "is_day,rain,showers,snowfall,weather_code,wind_speed_10m"
        "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max"
        "&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch"
        "&timezone=auto&forecast_days=1"
    )
    try:
        line = render(fetch_json(url))
    except Exception:
        # Keep showing the last good line; retry on the next poll.
        emit_cached(cache)
        save_cache(cache)  # persist a refreshed geolocation even on failure
        return

    cache.update({"ts": time.time(), "line": line})
    save_cache(cache)
    print(f" {line} ")


if __name__ == "__main__":
    main()
