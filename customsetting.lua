local addon, ns = ...

--SettingsCheckBoxMixin = CreateFromMixins(CallbackRegistryMixin, DefaultTooltipMixin);
SettingsButtonWithButtonControlMixin = CreateFromMixins(SettingsListElementMixin);
function SettingsButtonWithButtonControlMixin:OnLoad()
    SettingsListElementMixin.OnLoad(self);
    self.Button1 = CreateFrame("Button", nil, self, "UIPanelButtonTemplate");
    self.Button1:SetWidth(100, 22);

    self.Button2 = CreateFrame("Button", nil, self, "UIPanelButtonTemplate");
    self.Button2:SetWidth(100, 22);
end

function SettingsButtonWithButtonControlMixin:Init(initializer)
    SettingsListElementMixin.Init(self, initializer);
    self.Button1:SetText(self.data.button1.buttonText);
    self.Button1:SetScript("OnClick", self.data.button1.buttonClick);
    self.Button2:SetText(self.data.button2.buttonText);
    self.Button2:SetScript("OnClick", self.data.button2.buttonClick);
    if self.data.name == "" then
        self.Button1:SetPoint("LEFT", self.Text, "LEFT", 0, 0);
        self.Tooltip:Hide();
    else
        self.Button1:SetPoint("LEFT", self, "CENTER", -80, 0);
        self.Tooltip:Show();
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    self.Button2:SetPoint("LEFT", self.Button1, "RIGHT", 5, 0);
end

function SettingsButtonWithButtonControlMixin:Release()
    ---@diagnostic disable-next-line: param-type-mismatch
    self.Button1:SetScript("OnClick", nil);
    ---@diagnostic disable-next-line: param-type-mismatch
    self.Button2:SetScript("OnClick", nil);
    SettingsListElementMixin.Release(self);
end

function CreateSettingsButtonWithButtonInitializer(name, buttonText1, buttonClick1, buttonText2,
                                                   buttonClick2, tooltip)
    local data = {
        name = name,
        button1 = {
            buttonText = buttonText1,
            buttonClick = buttonClick1,
        },
        button2 = {
            buttonText = buttonText2,
            buttonClick = buttonClick2,
        },
        tooltip = tooltip,
    };
    local initializer = Settings.CreateElementInitializer("SettingsButtonWithButtonControlTemplate", data);
    initializer:AddSearchTags(name);
    initializer:AddSearchTags(buttonText1);
    initializer:AddSearchTags(buttonText2);
    return initializer;
end
