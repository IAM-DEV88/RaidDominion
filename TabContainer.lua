function QuickNameTabContainerInit()
        if not roleSelectionFrame then
            roleSelectionFrame = CreateFrame("Frame", nil, QuickNameRoleTab)
            roleSelectionFrame:SetPoint("TOP", -11, -24)
            roleSelectionFrame:SetSize(430, 230)

            local content = PlayerRolesTabContainerInit()
            content:SetParent(roleSelectionFrame)
            content:SetPoint("TOPLEFT")
            content:Show()
        end
        roleSelectionFrame:Show()
        if aboutFrame then
            aboutFrame:Hide()
        end
end