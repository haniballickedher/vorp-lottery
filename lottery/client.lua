local VORPcore = {} -- core object

TriggerEvent("getCore", function(core)
    VORPcore = core
end)
local VORPMenu = {}

TriggerEvent("vorp_menu:getData", function(cb)
    VORPMenu = cb
end)

--Following Thread looks for ped in radius of voting locations the in config and offers G for menu
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        for k, v in pairs(Config.LotteryLocations) do
            local distance = GetDistanceBetweenCoords(coords, v.coords.x, v.coords.y, v.coords.z, true)

            if distance < 2.0 then
                DrawTxt('Press G to Buy a Lottery Ticket', 0.50, 0.85, 0.7, 0.7, true, 255, 255, 255, 255, true)

                if IsControlJustReleased(0, 0x760A9C6F) then
                    local city = v.city
                    local region = v.region
                    TriggerEvent('lottery:booth', city, region)
                    Citizen.Wait(1000)
                end
            end
        end

        Citizen.Wait(0)
    end
end)

RegisterNetEvent('lottery:booth')
AddEventHandler('lottery:booth', function(city, region)
    OpenMainMenu()
end)

function OpenMainMenu()
    VORPMenu.CloseAll()
    local menuElements = {
        { label = "Exit Menu", value = "exit_menu", desc = "Close Menu" },
    }
    local addMenuElement
   -- addMenuElement = { label = "Results!", value = "results", desc = "Results" }
   -- table.insert(menuElements, 1, addMenuElement)
    addMenuElement = { label = "Enter Lotteries", value = "currentlotteries", desc = "Enter Lotteries" }
    table.insert(menuElements, 1, addMenuElement)
    -- Open the menu using VORPMenu
    VORPMenu.Open(
        "default",
        GetCurrentResourceName(),
        "mainmenu",
        {
            title = "Lottery",
            subtext = "",
            align = "top-center",
            elements = menuElements,
            itemHeight = "4vh",
        },
        function(data, menu)
            if data.current.value == "results" then
                OpenResultsMenu()
            elseif data.current.value == "currentlotteries" then
                OpenCurrentLotteryMenu()
            elseif data.current.value == "exit_menu" then
                print("close")
                menu.close()
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

function OpenResultsMenu()
    VORPMenu.CloseAll()
    local menuElements = {}
    local addMenuElement
    addMenuElement = { label = "Main Menu", value = "back", desc = "Back to Main Menu" }
    table.insert(menuElements, addMenuElement)
    addMenuElement = { label = "Exit Menu", value = "exit_menu", desc = "Close Menu" }
    table.insert(menuElements, addMenuElement)
    --Here need to get all prior lotteries names and list
    TriggerEvent("vorp:ExecuteServerCallBack", "lottery:getResults", function(cb)
        local result = cb
        if #cb == 0 then
            print("No lotteries found.")
            TriggerEvent("vorp:TipBottom", "No active lotteries", 4000)
        end

        for k, v in pairs(cb) do
            label = cb[k].lotteryname
            value = cb[k].lotteryid
            addMenuElement = { label = label, value = value, desc = "AddWinnerHere" }
            table.insert(menuElements, addMenuElement)
        end

        addMenuElement = { label = "Main Menu", value = "back", desc = "Back to Main Menu" }
        table.insert(menuElements, addMenuElement)
        addMenuElement = { label = "Exit Menu", value = "exit_menu", desc = "Close Menu" }
        table.insert(menuElements, addMenuElement)


        -- Open the menu using VORPMenu
        VORPMenu.Open(
            "default",
            GetCurrentResourceName(),
            "resultsmenu",
            {
                title = "View Lottery Results",
                subtext = "",
                align = "top-center",
                elements = menuElements,
                itemHeight = "4vh",
            },
            function(data, menu)
                if data.current.value == "back" then
                    OpenStartMenu()
                elseif data.current.value == "exit_menu" then
                    print("close")
                    menu.close()
                else
                    print("here")
                end
            end,
            function(data, menu)
                menu.close()
            end)
    end)
   
end

function OpenCurrentLotteryMenu()
    VORPMenu.CloseAll()
    local menuElements = {}
    local addMenuElement
    --db list of all current lotteries
    TriggerEvent("vorp:ExecuteServerCallBack", "lottery.getLotteries", function(cb)
        local result = cb
        if #cb == 0 then
            print("No lotteries found.")
            TriggerEvent("vorp:TipBottom", "No active lotteries", 4000)
        end

        for k, v in pairs(cb) do
            label = cb[k].lotteryname
            value = cb[k].id
            cost = cb[k].price
            addMenuElement = { label = label.." $"..cost, value = value, desc = "Enter this lottery for "..cost, cost= cost }
            table.insert(menuElements, addMenuElement)
        end
        addMenuElement = { label = "Main Menu", value = "back", desc = "Back to Main Menu" }
        table.insert(menuElements, addMenuElement)
        addMenuElement = { label = "Exit Menu", value = "exit_menu", desc = "Close Menu" }
        table.insert(menuElements, addMenuElement)
        -- Open the menu using VORPMenu
        VORPMenu.Open(
            "default",
            GetCurrentResourceName(),
            "buymenu",
            {
                title = "Buy Lottery Ticket",
                subtext = "Spiritwalker Business Lottery",
                align = "top-center",
                elements = menuElements,
                itemHeight = "4vh",
            },
            function(data, menu)
                if data.current.value == "back" then
                    OpenStartMenu()
                elseif data.current.value == "exit_menu" then
                    print("close")
                    menu.close()
                else
                    local lotteryid = data.current.value
                    local lotteryname = data.current.label
                    local lotterycost = data.current.cost
                    EnterLottery(lotteryid, lotteryname, lotterycost)
                end
            end,
            function(data, menu)
                menu.close()
            end)
    end)
end



function EnterLottery(lotteryid,lotteryname,lotterycost) 
    
    local lotID = lotteryid
    local cost = lotterycost
    TriggerEvent("vorp:ExecuteServerCallBack", "lottery:hasenteredalready", function(cb)
        local result = cb
        if cb then
            local button = "You have already entered this lottery.  Do you want to remain in the lottery?"
            local placeholder = "y or n"
            TriggerEvent("vorpinputs:getInput", button, placeholder, function(answer)
                print("User input received:", answer)
                if answer == "n" or answer == "N" then
                    TriggerServerEvent('removeentry', lotID)
                    TriggerEvent("vorp:TipBottom",
                        ("You have been removed from the lottery"),
                        4000)
                    OpenMainMenu()
                else
                    TriggerEvent("vorp:TipBottom", ("You remain entered in this lottery"), 4000)
                end
            end)
        else
            local button = "You are about to enter the lottery for "..lotteryname..".  It costs nonrefundable "..lotterycost.." to enter. Press y to confirm."
            local placeholder = "y or n"
            TriggerEvent("vorpinputs:getInput", button, placeholder, function(answer)
                print("User input received:", answer)
                if answer == "y" or answer == "Y" then
                    TriggerEvent("vorp:ExecuteServerCallBack", "lottery:enterlottery", function(cb)                          
                        VORPcore.NotifyTip(cb,4000) 
                        TriggerEvent("vorp:TipBottom", cb, 4000)
                    end,{ lotteryid = lotteryid, lotterycost = lotterycost })
                    OpenMainMenu()
                end
            end)
        end
    end,{ lotteryid = lotteryid })
end

function DrawTxt(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local str = CreateVarString(10, "LITERAL_STRING", str)
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
    SetTextCentre(centre)
    SetTextFontForCurrentCommand(15)
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
    --Citizen.InvokeNative(0xADA9255D, 1);
    DisplayText(str, x, y)
end

RegisterCommand("addLottery", function()
    TriggerEvent("vorp:ExecuteServerCallBack", "lottery:isAdmin", function(cb)
        local results = cb
        print(results)
        if results then
            AddNewLottery()
        else
            TriggerEvent("vorp:TipBottom", ("Only Election Officials are authorized to use this command. "), 4000)
        end
    end)
end)


RegisterCommand("runLotteries", function()
    TriggerServerEvent("lotterywinners")
    print('Updating Lottery Results')
end)

function AddNewLottery()
    local button = "Next"
    local placeholder = "Lottery Name"
    local inputType = "input" -- number ,textarea , date, etc.
    local lotteryname
    local daystoopen
    local price
    local description
    TriggerEvent("vorpinputs:getInput", button, placeholder, inputType, function(result)
        if result ~= "" or result then -- making sure its not empty or nil
            print(result)              -- returs a string
            lotteryname = result
        else
            print("its empty?") -- notify
        end
    end)
    placeholder = "Days to Open"
    inputType = number

    TriggerEvent("vorpinputs:getInput", button, placeholder, inputType, function(result)
        if result ~= "" or result then -- making sure its not empty or nil
            print(result)              -- returs a string
            daystoopen = result
        else
            print("its empty?") -- notify
        end
    end)
    placeholder = "Price to Enter"
    inputType = number

    TriggerEvent("vorpinputs:getInput", button, placeholder, inputType, function(result)
        if result ~= "" or result then -- making sure its not empty or nil
            print(result)              -- returs a string
            price = result
        else
            print("its empty?") -- notify
        end
    end)
    placeholder = "Description"
    inputType = textarea

    TriggerEvent("vorpinputs:getInput", button, placeholder, inputType, function(result)
        if result ~= "" or result then -- making sure its not empty or nil
            print(result)              -- returs a string
            description = result
        else
            print("its empty?") -- notify
        end
    end)
    TriggerServerEvent('addNewLottery', lotteryname, daystoopen, price, description)
end
local blipstable = {}


Citizen.CreateThread(function()
    Citizen.Wait(5000)
    for k,v in pairs(Config.LotteryLocations) do 
        local blip =  Citizen.InvokeNative(0x554D9D53F696D002,1664425300, v.coords.x, v.coords.y, v.coords.z) -- id
        SetBlipSprite(blip, v.hash, 1)
        SetBlipScale(blip, v.scale)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, v.name)
        table.insert(blipstable, blip)
    end
    for k,v in pairs(blipstable) do 
        print(v)
    end
end)