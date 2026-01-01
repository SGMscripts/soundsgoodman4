-- @description CSV → Meta markers for selected items from ucsify csv SGM.lua
-- @version 1.0
-- @author SGM
-- @about
--   Select item(s), choose a CSV file, META markers are generated
--   from CSV rows whose CreationDate falls within the item's
--   BWF origination time range.

----------------------------------------------------------
-- REQUIREMENTS CHECK
----------------------------------------------------------
if not reaper.CF_GetMediaSourceMetadata then
  reaper.MB("SWS Extension is required.", "Error", 0)
  return
end

----------------------------------------------------------
-- SETTINGS
----------------------------------------------------------
local META_AFTER_END_OFFSET = 0.0005
local META_SECOND_DELTA     = 0.001

----------------------------------------------------------
-- DateTime → seconds
----------------------------------------------------------
local function datetime_to_seconds(dt)
  local y,m,d,h,mi,s =
    dt:match("(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)")
  if not y then return nil end
  return os.time{
    year=y, month=m, day=d,
    hour=h, min=mi, sec=s
  }
end

----------------------------------------------------------
-- CSV loader (semicolon delimited)
----------------------------------------------------------
local function load_csv(path)
  local rows = {}
  local f = io.open(path, "r")
  if not f then return rows end

  f:read("*l") -- skip header

  for line in f:lines() do
    local cols = {}
    for v in line:gmatch("([^;]*)") do
      cols[#cols+1] = v
    end
    rows[#rows+1] = cols
  end

  f:close()
  return rows
end

----------------------------------------------------------
-- Get BWF time range for item
----------------------------------------------------------
local function get_item_bwf_range(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil end

  local src = reaper.GetMediaItemTake_Source(take)

  local _, d = reaper.CF_GetMediaSourceMetadata(
    src, "BWF:OriginationDate", ""
  )
  local _, t = reaper.CF_GetMediaSourceMetadata(
    src, "BWF:OriginationTime", ""
  )

  if d == "" or t == "" then return nil end

  local start_sec =
    datetime_to_seconds(d .. " " .. t)
  if not start_sec then return nil end

  local len =
    reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  return start_sec, start_sec + len, d, t
end

----------------------------------------------------------
-- Build Soundminer META marker from CSV row
----------------------------------------------------------
local function build_meta_from_csv(row, odate, otime)
  local categoryFull =
    (row[6] or "") .. "-" .. (row[7] or "")

  return
    "META;" ..
    "CatID=" .. (row[5] or "") .. ";" ..
    "Category=" .. (row[6] or "") .. ";" ..
    "SubCategory=" .. (row[7] or "") .. ";" ..
    "UserCategory=" .. (row[14] or "") .. ";" ..
    "VendorCategory=" .. (row[20] or "") .. ";" ..
    "FXName=" .. (row[2] or "") .. ";" ..
    "Notes=" .. (row[4] or "") .. ";" ..
    "Show=" .. (row[19] or "") .. ";" ..
    "CategoryFull=" .. categoryFull .. ";" ..
    "TrackTitle=" .. (row[3] or "") .. ";" ..
    "Description=" .. (row[3] or "") .. ";" ..
    "Keywords=" .. (row[9] or "") .. ";" ..
    "RecMedium=" .. (row[15] or "") .. ";" ..
    "Library=;" ..
    "Location=" .. (row[10] or "") .. ";" ..
    "URL=;" ..
    "Manufacturer=;" ..
    "MetaNotes=;" ..
    "MicPerspective=" .. (row[12] or "") .. ";" ..
    "RecType=" .. (row[16] or "") .. ";" ..
    "Microphone=" .. (row[11] or "") .. ";" ..
    "Designer=" .. (row[8] or "") .. ";" ..
    "ShortID=" .. (row[8] or "") .. ";" ..
    'Filename="' .. (row[2] or "") .. '";' ..
    "OriginationDate=" .. (odate or "") .. ";" ..
    "OriginationTime=" .. (otime or "")
end

----------------------------------------------------------
-- MAIN
----------------------------------------------------------
local selCount = reaper.CountSelectedMediaItems(0)
if selCount == 0 then
  reaper.MB("Select at least one item.", "Error", 0)
  return
end

local ok, csvPath = reaper.GetUserFileNameForRead(
  "", "Select CSV file", ".csv"
)
if not ok then return end

local csv = load_csv(csvPath)
if #csv == 0 then
  reaper.MB("CSV is empty or invalid.", "Error", 0)
  return
end

reaper.Undo_BeginBlock()

for i = 0, selCount - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)

  local startSec, endSec, odate, otime =
    get_item_bwf_range(item)

  if startSec then
    local metas = {}

    for _, row in ipairs(csv) do
      local csvTime = datetime_to_seconds(row[1])
      if csvTime and csvTime >= startSec and csvTime <= endSec then
        metas[#metas+1] =
          build_meta_from_csv(row, odate, otime)
      end
    end

    if #metas > 0 then
      local itemStart =
        reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local itemEnd =
        itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

      local pos = itemEnd + META_AFTER_END_OFFSET

      for _, meta in ipairs(metas) do
        reaper.AddProjectMarker(0, false, pos, 0, meta, -1)
        pos = pos + META_SECOND_DELTA
      end

      reaper.AddProjectMarker(0, false, pos, 0, "META", -1)
    end
  end
end

reaper.Undo_EndBlock("CSV → Soundminer META markers by BWF time", -1)

