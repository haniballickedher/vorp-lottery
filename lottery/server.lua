VORP = exports.vorp_core:vorpAPI()
local VorpCore = {}
local ServerRPC = exports.vorp_core:ServerRpcCall() --[[@as ServerRPC]] -- for intellisense
local VORPutils = {}

TriggerEvent("getUtils", function(utils)
  VORPutils = utils
end)
TriggerEvent("getCore", function(core)
  VorpCore = core
end)




VORP.addNewCallBack("lottery:checkifentered", function(source, cb, params)
  local _source = source
  local User = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
  local lottery = params.lotteryid
  local isEntered = false -- Initialize the variable
  MySQL.single('SELECT * FROM lotterytickets WHERE charid = ?', { charId },
    function(row)
      if not row then
        isEntered = false
      else
        isEntered = true
      end
      cb(isEntered) -- Call the callback with the result
    end
  )
end)



VORP.addNewCallBack("lottery:isAdmin", function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)

  local isAllowed = false
  for k, v in pairs(Config.ElectionOfficials) do
    for _, group in ipairs(v) do
      if group == user.getGroup then
        isAllowed = true
        break
      end
    end
    if isAllowed then
      break
    end
  end

  cb(isAllowed)

end)



VORP.addNewCallBack("lottery:getResults", function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
  local query
  query = 'SELECT * from lotteries where open = 0'
  MySQL.query(query, queryParams, function(result)
    cb(result)
  end)
end)


VORP.addNewCallBack("lottery.getLotteries", function(source, cb, params)
  local query
  query = 'SELECT * from lotteries where open = 1'
  MySQL.query(query, queryParams, function(result)
    cb(result)
  end)
end)

VORP.addNewCallBack('lottery:hasenteredalready', function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
  local lotteryid = params.lotteryid
  local query, queryParams

  query = 'SELECT * from lotterytickets where charID=@charId and lotteryid = @lotteryid '
  queryParams = { ['@lotteryid'] = lotteryid, ['@charId'] = charId }

  MySQL.query(query, queryParams, function(result)
    -- Check if there is at least one row in the result
    local hasEntered = #result > 0
    print("has entered", hasEntered)
    cb(hasEntered)
  end)
end)


RegisterServerEvent('addNewLottery')
AddEventHandler('addNewLottery', function(lotteryname, daystoopen, price, description)
  query =
  'INSERT INTO lotteries (lotteryname, days, end, open, price, desc) VALUES (@lotteryname, @daystoopen,  1, @price, @description)) '
  queryParams = {
    ['@lotteryname'] = lotteryname,
    ['@daystoopen'] = daystoopen,
    ['@price'] = price,
    ['@description'] =
        description
  }
  MySQL.Async.execute(query, queryParams)
end)

RegisterServerEvent('removeentry')
AddEventHandler('removeentry', function(lotteryid)
  local _source = source
  local User = VorpCore.getUser(_source)
  local charId = (User.getUsedCharacter).charIdentifier
  query = 'DELETE FROM lotterytickets where lotteryid= @lotteryid and charid=@charid '
  queryParams = { ['@lotteryid'] = lotteryid, ['@charid'] = charId, }
  MySQL.Async.execute(query, queryParams)
end)


VORP.addNewCallBack('lottery:enterlottery', function(source, cb, params)
  local _source = source
  local User = VorpCore.getUser(_source)
  local Character = User.getUsedCharacter
  local charId = (User.getUsedCharacter).charIdentifier

  local message = ""
  local cost = params.lotterycost
  local lotteryid = params.lotteryid
  print (Character.money.." "..cost)
  if Character.money >= cost then
    Character.removeCurrency(0, cost) 
    query = 'INSERT INTO lotterytickets (lotteryid, charid) VALUES (@lotteryid, @charid) '
    queryParams = { ['@lotteryid'] = lotteryid, ['@charid'] = charId, }
    MySQL.Async.execute(query, queryParams)
    message = "You paid "..cost.." and entered the lottery"
    cb(message)
  else 
    message = "You do not have enough money to enter this lottery."
    cb(message) 
  end
end)

RegisterServerEvent('lotterywinners')
AddEventHandler('lotterywinners', function()
  -- Select lotteries that should be completed
  print('Updating Lottery Results Server Side')

  MySQL.query('SELECT id, lotteryname FROM lotteries WHERE END < NOW() and open =1', {}, function(result)
    if result then

      for _, row in ipairs(result) do
        local closelotteryid = row.id
        print('Lottery ID:', closelotteryid..row.lotteryname)
        local closelotteryname = row.lotteryname
        MySQL.query('SELECT * FROM lotterytickets WHERE lotteryid = ?', { closelotteryid }, function(entries)
          if entries then
            print(#entries .. " entries")

            -- Check if there are entries before attempting to select a winner
            if #entries > 0 then
              local winningIndex = math.random(1, #entries)
              local winningEntry = entries[winningIndex]
             

              -- Update the lotterytickets table to mark the winner
              local affectedRows = MySQL.update.await('UPDATE lotterytickets SET winner = 1 WHERE ticketid = ?', { winningEntry.ticketid })
               print( affectedRows)
               
                    print('Winner updated in lotterytickets table. charid'..winningEntry.charid.." lotteryid: "..winningEntry.ticketid)

                    -- Update the lotteries table with the charid of the winner

                    local updateLottery = MySQL.update.await('UPDATE lotteries SET open = 0, winnercharid = ? WHERE id = ?', { winningEntry.charid, closelotteryid })
                    print (updateLottery .."did that work?")
                  print("lottery updated. won by"..winningEntry.charid)
                  local winner = MySQL.single.await('SELECT firstname, lastname from characters where charidentifier = ?', {winningEntry.charid})
                  if winner then
                    print("winner:"..winner.firstname.." "..winner.lastname)
                    local webhooktitle = "Lottery Ended:  "..closelotteryname
                    local webhookdesc = "Winner:"..winner.firstname.." "..winner.lastname
                  
                    SendToDiscordWebhook(webhooktitle, webhookdesc)
                  end
            else
              print('No entries to select a winner from')
            end
          else
            print('Error fetching entries for Lottery ID:', closelotteryid)
          end
        end)
      end
    else
      print("Error fetching lotteries")
    end
  end)
end)


function SendToDiscordWebhook(title, description)
  local name = Config.Webhooks.WebhookName
  local color = Config.Webhooks.Color
  local webhook = Config.Webhooks.URL
  local logo = Config.Webhooks.WebhookLogo
  local footerlogo = ""
  local avatar = ""
  VorpCore.AddWebhook(title, webhook, description, color, name, logo, footerlogo, avatar)
end
