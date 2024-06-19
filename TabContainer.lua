function RaidDominionTabContainerInit()
        if not roleSelectionFrame then
            roleSelectionFrame = CreateFrame("Frame", nil, RaidDominionRoleTab)
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