

local addonName, TbdAltManagerDailyQuests = ...;

local playerUnitToken = "player";

local ThisCharacter;

--Callback registry
TbdAltManagerDailyQuests.CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
TbdAltManagerDailyQuests.CallbackRegistry:OnLoad()
TbdAltManagerDailyQuests.CallbackRegistry:GenerateCallbackEvents({
    "Character_OnAdded",
    "Character_OnChanged",
    "Character_OnRemoved",
    "Quest_OnLogScanned",
    "Quest_OnTurnedIn",
    "Quest_OnAccepted",
    "Quest_OnTrackingChanged",
    "DataProvider_OnInitialized",
})


local characterDefaults = {
    uid = "",
    quests = {},
}

local characterDefaultsToRemove = {

}

--Main DataProvider for the module
local CharacterDataProvider = CreateFromMixins(DataProviderMixin)

function CharacterDataProvider:InsertCharacter(characterUID)

    local character = self:FindElementDataByPredicate(function(characterData)
        return (characterData.uid == characterUID)
    end)

    if not character then        
        local newCharacter = {}
        for k, v in pairs(characterDefaults) do
            newCharacter[k] = v
        end

        newCharacter.uid = characterUID

        self:Insert(newCharacter)
        TbdAltManagerDailyQuests.CallbackRegistry:TriggerEvent("Character_OnAdded")
    end
end

function CharacterDataProvider:FindCharacterByUID(characterUID)
    return self:FindElementDataByPredicate(function(character)
        return (character.uid == characterUID)
    end)
end

function CharacterDataProvider:UpdateDefaultKeys()
    for _, character in self:EnumerateEntireRange() do
        for k, v in pairs(characterDefaults) do
            if character[k] == nil then
                character[k] = v;
            end
        end
    end
end










TbdAltManagerDailyQuests.Api = {}

function TbdAltManagerDailyQuests.Api.SetTracking(questID, thisCharacterOnly)

    if thisCharacterOnly == true then
        --table.insert(ThisCharacter.quests, questID)
        if ThisCharacter.quests[questID] == nil then
            ThisCharacter.quests[questID] = {
                lastTurnIn = 0
            }
        end
    else
        for _, character in CharacterDataProvider:EnumerateEntireRange() do
            --table.insert(character.quests, questID)
            if character.quests[questID] == nil then
                character.quests[questID] = {
                    lastTurnIn = 0,
                }
            end
        end
        TbdAltManager_QuestTracking[questID] = true
    end

    TbdAltManagerDailyQuests.CallbackRegistry:TriggerEvent("Quest_OnTrackingChanged", questID)

end

-- local function RemoveQuest(t, questID)
--     local keyToRemove;
--     for k, qid in ipairs(t) do
--         if qid == questID then
--             keyToRemove = k
--         end
--     end
--     if keyToRemove then
--         table.remove(t, keyToRemove)
--     end
-- end

function TbdAltManagerDailyQuests.Api.RemoveTracking(questID, thisCharacterOnly, characterUID)

    if characterUID then
        local character = CharacterDataProvider:FindCharacterByUID(characterUID)
        if character then
            character.quests[questID] = nil
        end
    else
        if thisCharacterOnly == true then
            --RemoveQuest(ThisCharacter.quests, questID)
            ThisCharacter.quests[questID] = nil
        else
            for _, character in CharacterDataProvider:EnumerateEntireRange() do
                --RemoveQuest(character.quests, questID)
                character.quests[questID] = nil
            end
            TbdAltManager_QuestTracking[questID] = nil
        end
    end

    TbdAltManagerDailyQuests.CallbackRegistry:TriggerEvent("Quest_OnTrackingChanged", questID)
end

function TbdAltManagerDailyQuests.Api.InitializeCharacterTracking(character)
    if TbdAltManager_QuestTracking then
        for questID, _ in pairs(TbdAltManager_QuestTracking) do
            character.quests[questID] = {
                lastTurnIn = 0
            }
        end
    end
end








local eventsToRegister = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "QUEST_ACCEPTED",
    "QUEST_TURNED_IN",
}

--Frame to setup event listening
local DailyQuestsEventFrame = CreateFrame("Frame")
for _, event in ipairs(eventsToRegister) do
    DailyQuestsEventFrame:RegisterEvent(event)
end
DailyQuestsEventFrame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

function DailyQuestsEventFrame:InitializeCharacter(isInitial, isReload)
   
    local account = "Default"
    local realm = GetRealmName()
    local name = UnitName(playerUnitToken)

    self.characterUID = string.format("%s.%s.%s", account, realm, name)

    CharacterDataProvider:InsertCharacter(self.characterUID)

    ThisCharacter = CharacterDataProvider:FindCharacterByUID(self.characterUID)

    TbdAltManagerDailyQuests.Api.InitializeCharacterTracking(ThisCharacter)

    self:ScanQuestLog()

end

function DailyQuestsEventFrame:ADDON_LOADED(...)
    if (... == addonName) then
        if TbdAltManager_DailyQuests == nil then

            CharacterDataProvider:Init({})
            TbdAltManager_DailyQuests = CharacterDataProvider:GetCollection()
    
        else
    
            local data = TbdAltManager_DailyQuests
            CharacterDataProvider:Init(data)
            TbdAltManager_DailyQuests = CharacterDataProvider:GetCollection()
    
        end

        CharacterDataProvider:UpdateDefaultKeys()

        if not CharacterDataProvider:IsEmpty() then
            TbdAltManagerDailyQuests.CallbackRegistry:TriggerEvent("DataProvider_OnInitialized")
        end


        if TbdAltManager_QuestData == nil then
            TbdAltManager_QuestData = {}
        end

        if TbdAltManager_QuestTracking == nil then
            TbdAltManager_QuestTracking = {}
        end


    end
end

function DailyQuestsEventFrame:PLAYER_ENTERING_WORLD(...)
    local isInitial, isReload = ...;
    C_Timer.After(1.0, function()
        self:InitializeCharacter(isInitial, isReload)
    end)
end

function DailyQuestsEventFrame:QUEST_ACCEPTED(...)
    C_Timer.After(1.0, function()
        self:ScanQuestLog()
    end)
end

function DailyQuestsEventFrame:QUEST_TURNED_IN(...)
    local questID, xp, copper = ...
    ThisCharacter.quests[questID] = {
        lastTurnIn = GetServerTime(),
        lastRewards = {
            xp = xp,
            copper = copper,
        },
    }
    TbdAltManagerDailyQuests.CallbackRegistry:TriggerEvent("Quest_OnTurnedIn", questID, xp, copper)
end

function DailyQuestsEventFrame:ScanQuestLog()
    local lastHeader;
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        --if info and ((info.frequency == 1) or (info.frequency == 2)) then
        if info then
            if info.isHeader then
                lastHeader = info.title
            end
            if info.frequency == 1 then
                --print("added", info.questID)
                local questLink = GetQuestLink(info.questID)
                TbdAltManager_QuestData[info.questID] = {
                    title = info.title,
                    level = info.level,
                    difficultyLevel = info.difficultyLevel,
                    --frequency = info.frequency,
                    header = lastHeader,
                    link = questLink,
                    questID = info.questID,
                }
            elseif info.frequency == 2 then
                --print(string.format("Found frequecy of 2, quest: %s", info.title))
            else
                TbdAltManager_QuestData[info.questID] = nil
            end
        end
    end
    TbdAltManagerDailyQuests.CallbackRegistry:TriggerEvent("Quest_OnLogScanned")

end












TbdAltManagerDailyQuestsListItemMixin = {}
function TbdAltManagerDailyQuestsListItemMixin:OnLoad()

end
function TbdAltManagerDailyQuestsListItemMixin:OnEnter()
    if self.questInfo and self.questInfo.link then
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetHyperlink(self.questInfo.link)
        GameTooltip:AddLine(self.questInfo.frequency)
        GameTooltip:AddLine(self.questInfo.level)
        GameTooltip:Show()
    end
end
function TbdAltManagerDailyQuestsListItemMixin:OnLeave()
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
end






--baseDb
TbdAltManagerDailyQuestTrackingBaseDbListItemMixin = {}
function TbdAltManagerDailyQuestTrackingBaseDbListItemMixin:OnLoad()
    self.TrackingMenuButton:SetScript("OnClick", function()
        if self.questInfo and self.questInfo.questID then
            MenuUtil.CreateContextMenu(self.TrackingMenuButton, function(_, rootDescription)
                rootDescription:CreateButton("All characters", function()
                    TbdAltManagerDailyQuests.Api.SetTracking(self.questInfo.questID, false)
                end)
                rootDescription:CreateButton("This character", function()
                    TbdAltManagerDailyQuests.Api.SetTracking(self.questInfo.questID, true)
                end)
            end)
        end
    end)
end
function TbdAltManagerDailyQuestTrackingBaseDbListItemMixin:SetDataBinding(binding)
    self.Label:SetText(binding.title)
    self.questInfo = binding
    if binding.isHeader then
        self.TrackingMenuButton:Hide()
        self.Label:SetFontObject(GameFontNormal)
    else
        self.TrackingMenuButton:Show()
        self.Label:SetFontObject(GameFontWhite)
    end
end
function TbdAltManagerDailyQuestTrackingBaseDbListItemMixin:ResetDataBinding()
    self.Label:SetText("")
    self.questInfo = nil
    self.TrackingMenuButton:Hide()
    self.Label:SetFontObject(GameFontNormal)
end



TbdAltManagerDailyQuestTrackingAllListItemMixin = {}
function TbdAltManagerDailyQuestTrackingAllListItemMixin:OnLoad()
    self.RemoveTracking:SetScript("OnClick", function()
        if self.questID then
            MenuUtil.CreateContextMenu(self.TrackingMenuButton, function(_, rootDescription)
                rootDescription:CreateButton("All characters", function()
                    TbdAltManagerDailyQuests.Api.RemoveTracking(self.questID, false)
                end)
                rootDescription:CreateButton("This character", function()
                    TbdAltManagerDailyQuests.Api.RemoveTracking(self.questID, nil, self.characterUID)
                end)
            end)
        end
    end)
end
function TbdAltManagerDailyQuestTrackingAllListItemMixin:SetDataBinding(binding)

    self.characterUID = binding.uid
    
    --header for character
    if binding.name then
        self.Label:SetFontObject(GameFontNormal)
        self.Label:SetText(binding.name)
        self.RemoveTracking:Hide()
    
    
    elseif binding.questData and binding.questInfo then
        self.Label:SetFontObject(GameFontWhite)
        self.questID = binding.questData.questID
        self.RemoveTracking:Show()

        self.questInfo = binding.questInfo

        local secondsToReset = C_DateAndTime.GetSecondsUntilDailyReset()
        local resetTime = GetServerTime() + secondsToReset
        local previousResetTime = resetTime - (24 * 60 * 60)
        local atlas;
        if binding.questInfo.lastTurnIn > previousResetTime then
            atlas = "common-icon-checkmark"
        else
            atlas = "common-icon-redx"
        end
        self.Label:SetText(string.format("%s %s", CreateAtlasMarkup(atlas, 16, 16), binding.questData.title))
    end
end
function TbdAltManagerDailyQuestTrackingAllListItemMixin:ResetDataBinding(binding)
    self.Label:SetText("")
    self.questID = nil
    self.RemoveTracking:Hide()
    self.characterUID = nil
    self.questInfo = nil
end








TbdAltManagerDailyQuestsMixin = {
    name = "DailyQuests",
    menuEntry = {
        height = 40,
        template = "TbdAltManagerSideBarListviewItemTemplate",
        initializer = function(frame)
            frame.Label:SetText("Daily Quests")
            frame.Icon:SetAtlas("quest-recurring-available")
            frame:SetScript("OnMouseUp", function()
                TbdAltsManager.Api.SelectModule("DailyQuests")
            end)
            --MenuEntryToggleButton = frame.ToggleButton
            TbdAltsManager.Api.SetupSideMenuItem(frame, false, false)
        end,
    }
}
function TbdAltManagerDailyQuestsMixin:OnLoad()
    TbdAltsManager.Api.RegisterModule(self)

    TbdAltManagerDailyQuests.CallbackRegistry:RegisterCallback("Quest_OnTrackingChanged", self.Quest_OnTrackingChanged, self)
end

function TbdAltManagerDailyQuestsMixin:OnShow()
    self:LoadBaseDb()
    self:LoadAllCharacterQuests()
end

function TbdAltManagerDailyQuestsMixin:LoadBaseDb()
    
    local nodes = {}
    local DataProvider = CreateTreeDataProvider()

    for questID, questInfo in pairs(TbdAltManager_QuestData) do

        if not nodes[questInfo.header] then
            nodes[questInfo.header] = DataProvider:Insert({
                title = questInfo.header,
                isHeader = true,
            })
        end

        local entry = {}
        for k, v in pairs(questInfo) do
            entry[k] = v
        end
        entry.isBaseDb = true

        nodes[questInfo.header]:Insert(entry)
    end

    self.QuestList.scrollView:SetDataProvider(DataProvider)
end

function TbdAltManagerDailyQuestsMixin:LoadAllCharacterQuests()
    
    local nodes = {}
    local DataProvider = CreateTreeDataProvider()

    for _, character in CharacterDataProvider:EnumerateEntireRange() do
        
        local node = DataProvider:Insert({
            name = character.uid
        })

        for questID, info in pairs(character.quests) do
            local questData = TbdAltManager_QuestData[questID]
            if questData then
                --DevTools_Dump({questData})
                node:Insert({
                    questData = questData,
                    questInfo = info,
                    uid = character.uid,
                })
            end
        end
    end

    self.TrackedQuestList.scrollView:SetDataProvider(DataProvider)
end

function TbdAltManagerDailyQuestsMixin:Quest_OnTrackingChanged(questID)
    self:LoadAllCharacterQuests()
end
