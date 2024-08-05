local addonName, addon = ...

-- 전역 변수 초기화 (SavedVariables에서 사용)
GuildMemberTrackerDB = GuildMemberTrackerDB or {}

-- 프레임 생성 및 이벤트 등록
local frame = CreateFrame("Frame")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_LOGIN")

-- 업데이트 지연 타이머
local updateTimer = nil

-- 최초 길드 멤버 목록을 저장할 변수
local firstGuildMembers = {}

-- 직업별 기본 인사말 테이블
local defaultGreetingMessages = {
    ["WARRIOR"] = "어서오세요 던전과 전장을 지배하는 %s님!",
    ["PALADIN"] = "어서오세요 성스러운 빛의 수호자 %s님!",
    ["HUNTER"] = "어서오세요 숲과 들판의 지배자 %s님!",
    ["ROGUE"] = "어서오세요 어둠 속에서 길을 찾는 %s님!",
    ["PRIEST"] = "어서오세요 신성한 치유의 대가 %s님!",
    ["SHAMAN"] = "어서오세요 원소의 지배자 %s님!",
    ["MAGE"] = "어서오세요 신비한 마법의 대가 %s님!",
    ["WARLOCK"] = "어서오세요 어둠의 지배자 %s님!",
    ["MONK"] = "어서오세요 자연의 수호자 %s님!",
    ["DEATHKNIGHT"] = "어서오세요 죽음을 다스리는 %s님!",
    ["DRUID"] = "어서오세요 균형과 조화의 달인 %s님!",
    ["DEMONHUNTER"] = "어서오세요 어둠 속의 복수자 %s님!",
    ["EVOKER"] = "어서오세요 고대의 기억을 가진 %s님!"
}

-- 서버명을 제거하는 함수
local function RemoveServerName(name)
    return string.gsub(name, "-.+", "")
end

-- 길드 채팅으로 메시지 전송 함수 (지연 시간 추가)
local function SendDelayedGuildMessage(message)
    local delay = math.random(10, 15)
    C_Timer.After(delay, function()
        SendChatMessage(message, "GUILD")
    end)
end

-- 두 멤버 목록을 비교하는 함수
local function compareMemberLists(firstList, currentList)
    local newMembers = {}
    local firstMemberMap = {}
    
    -- 최초 멤버 목록을 맵으로 변환
    for _, member in ipairs(firstList) do
        firstMemberMap[member.name] = true
    end
    
    -- 현재 멤버 목록과 비교
    for _, member in ipairs(currentList) do
        if not firstMemberMap[member.name] then
            table.insert(newMembers, member)
        end
    end
    
    return newMembers
end

-- 오프라인 멤버를 firstGuildMembers에서 제거하는 함수
local function removeOfflineMembers(currentMembers)
    local onlineMemberMap = {}
    for _, member in ipairs(currentMembers) do
        onlineMemberMap[member.name] = true
    end
    
    for i = #firstGuildMembers, 1, -1 do
        if not onlineMemberMap[firstGuildMembers[i].name] then
            table.remove(firstGuildMembers, i)
        end
    end
end

-- 길드 멤버 정보 수집 및 저장 함수
local function UpdateGuildMembers()
    local members = {}
    local numTotalMembers, numOnlineMembers = GetNumGuildMembers()
    for i = 1, numTotalMembers do
        local name, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
        if online then
            table.insert(members, {name = name, class = class})
        end
    end
    
    -- 온라인 멤버가 있을 때만 처리
    if #members > 0 then
        if #firstGuildMembers == 0 then
            -- 최초 업데이트인 경우
            firstGuildMembers = members
        else
            -- 오프라인 멤버 제거
            removeOfflineMembers(members)
            
            -- 새로운 멤버 확인
            local newMembers = compareMemberLists(firstGuildMembers, members)
            
            if #newMembers > 0 then
                for _, member in ipairs(newMembers) do
                    local greetingMessage = defaultGreetingMessages[member.class] or "어서오세요 %s님!"
                    local nameWithoutServer = RemoveServerName(member.name)
                    SendDelayedGuildMessage(string.format(greetingMessage, nameWithoutServer))
                    table.insert(firstGuildMembers, member)
                end
            end
        end
        
        GuildMemberTrackerDB.members = members
        GuildMemberTrackerDB.lastUpdate = date("%Y-%m-%d %H:%M:%S")
    else
        C_Timer.After(5, function()
            GuildRoster()
        end)
    end
end

-- 이벤트 처리 함수
local function OnEvent(self, event)
    if event == "PLAYER_LOGIN" then
        -- 로그인 시 길드 정보 업데이트 요청
        GuildRoster()
    elseif event == "GUILD_ROSTER_UPDATE" then
        -- 타이머가 이미 실행 중이면 취소
        if updateTimer then
            updateTimer:Cancel()
        end
        -- 2초 후에 업데이트 실행 (마지막 이벤트 발생 후 2초 대기)
        updateTimer = C_Timer.NewTimer(2, UpdateGuildMembers)
    end
end

frame:SetScript("OnEvent", OnEvent)

-- 슬래시 명령어 등록
SLASH_GUILDMEMBERS1 = "/guildmembers"
SlashCmdList["GUILDMEMBERS"] = function()
    GuildRoster() -- 길드 정보 업데이트 요청
end

-- 저장된 데이터 출력 함수
local function PrintSavedMembers()
    if GuildMemberTrackerDB.members and #GuildMemberTrackerDB.members > 0 then
        print("저장된 길드 멤버 목록 (마지막 업데이트: " .. (GuildMemberTrackerDB.lastUpdate or "Unknown") .. "):")
        for i, member in ipairs(GuildMemberTrackerDB.members) do
            print(i .. ". " .. RemoveServerName(member.name) .. " (" .. member.class .. ")")
        end
    else
        print("저장된 길드 멤버 정보가 없거나 온라인 멤버가 없습니다.")
    end
end

-- 저장된 데이터 출력을 위한 슬래시 명령어
SLASH_PRINTGUILDMEMBERS1 = "/printguildmembers"
SlashCmdList["PRINTGUILDMEMBERS"] = PrintSavedMembers