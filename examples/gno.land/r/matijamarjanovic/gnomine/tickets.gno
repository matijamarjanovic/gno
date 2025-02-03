package gnomine

import (
	"errors"
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/tokenhub"
	"gno.land/p/demo/avl"
	"gno.land/p/demo/avl/pager"
)

var (
	ticketCounter  uint64
)

func init() {
	ticketCounter = 0
}

// CreateCoinToTokenTicket creates a ticket to swap native coins for GRC20 tokens.
// The coins to be swapped must be sent with the transaction. They will be locked in the realm until
// one of the following happens:
// - the ticket is fulfilled
// - the ticket is cancelled
// - the ticket expires
func CreateCoinToTokenTicket(
	coinDenom string,     // e.g. "ugnot"
	tokenKey string,      // e.g. "gno.land/r/test.gtoken"
	minAmountOut uint64,  // minimum amount of tokens to receive
	expiryHours int64,
) (string, error) {
	caller := std.PrevRealm().Addr()

	sent := std.GetOrigSend()
	if len(sent) != 1 || sent[0].Denom != coinDenom {
		return "", errors.New("sent coins don't match ticket parameters")
	}
	amountIn := uint64(sent[0].Amount)

	tokenOut := tokenhub.GetToken(tokenKey)
	if tokenOut == nil {
		return "", errors.New("token not found: " + tokenKey)
	}

	ticketCounter++
	ticketID := ufmt.Sprintf("TICKET-%d", ticketCounter)
	
	ticket := &Ticket{
		ID:           ticketID,
		Creator:      caller,
		AssetIn:      NewCoinAsset(coinDenom),
		AssetOut:     NewTokenAsset(tokenKey),
		AmountIn:     amountIn,
		MinAmountOut: minAmountOut,
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().Add(time.Duration(expiryHours) * time.Hour),
		Status:       "open",
	}

	ticketRegistry.tickets.Set(ticketID, ticket)
	return ticketID, nil
}

// CreateTokenToCoinTicket creates a ticket to swap GRC20 tokens for native coins.
// Requires token approval before creating the ticket.
func CreateTokenToCoinTicket(
	tokenKey string,      // e.g. "gno.land/r/test.gtoken"
	coinDenom string,     // e.g. "ugnot"
	amountIn uint64,      // amount of tokens to swap
	minAmountOut uint64,  // minimum amount of coins to receive
	expiryHours int64,
) (string, error) {
	caller := std.PrevRealm().Addr()

	tokenIn := tokenhub.GetToken(tokenKey)
	if tokenIn == nil {
		return "", errors.New("token not found: " + tokenKey)
	}

	tellerIn := tokenIn.RealmTeller()
	if err := tellerIn.TransferFrom(caller, std.CurrentRealm().Addr(), amountIn); err != nil {
		return "", errors.New("failed to transfer tokens: " + err.Error())
	}

	ticketCounter++
	ticketID := ufmt.Sprintf("TICKET-%d", ticketCounter)
	
	ticket := &Ticket{
		ID:           ticketID,
		Creator:      caller,
		AssetIn:      NewTokenAsset(tokenKey),
		AssetOut:     NewCoinAsset(coinDenom),
		AmountIn:     amountIn,
		MinAmountOut: minAmountOut,
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().Add(time.Duration(expiryHours) * time.Hour),
		Status:       "open",
	}

	ticketRegistry.tickets.Set(ticketID, ticket)
	return ticketID, nil
}

// CreateTokenToTokenTicket creates a ticket to swap one GRC20 token for another.
// Requires token approval before creating the ticket.
func CreateTokenToTokenTicket(
	tokenInKey string,    // e.g. "gno.land/r/test1.gtokenA"
	tokenOutKey string,   // e.g. "gno.land/r/test2.gtokenB"
	amountIn uint64,      // amount of tokens to swap
	minAmountOut uint64,  // minimum amount of tokens to receive
	expiryHours int64,
) (string, error) {
	caller := std.PrevRealm().Addr()

	tokenIn := tokenhub.GetToken(tokenInKey)
	if tokenIn == nil {
		return "", errors.New("token not found: " + tokenInKey)
	}

	tokenOut := tokenhub.GetToken(tokenOutKey)
	if tokenOut == nil {
		return "", errors.New("token not found: " + tokenOutKey)
	}

	tellerIn := tokenIn.RealmTeller()
	if err := tellerIn.TransferFrom(caller, std.CurrentRealm().Addr(), amountIn); err != nil {
		return "", errors.New("failed to transfer tokens: " + err.Error())
	}

	ticketCounter++
	ticketID := ufmt.Sprintf("TICKET-%d", ticketCounter)
	
	ticket := &Ticket{
		ID:           ticketID,
		Creator:      caller,
		AssetIn:      NewTokenAsset(tokenInKey),
		AssetOut:     NewTokenAsset(tokenOutKey),
		AmountIn:     amountIn,
		MinAmountOut: minAmountOut,
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().Add(time.Duration(expiryHours) * time.Hour),
		Status:       "open",
	}

	ticketRegistry.tickets.Set(ticketID, ticket)
	return ticketID, nil
} 

// FulfillTicket allows a user to fulfill an open ticket.
// If all checks pass, the ticket is fulfilled and the assets are transferred to both parties.
//
// note: If the ticket is asking for coins, the amountOut must be the exact amount of coins sent.
func FulfillTicket(ticketID string, amountOut uint64) error {
	caller := std.PrevRealm().Addr()
	
	ticketInterface, exists := ticketRegistry.tickets.Get(ticketID)
	if !exists {
		return errors.New("ticket not found")
	}
	
	ticket := ticketInterface.(*Ticket)

	if ticket.Status != "open" {
		return errors.New("ticket is not open")
	}

	if time.Now().After(ticket.ExpiresAt) {
		ticket.Status = "expired"
		ticketRegistry.tickets.Set(ticketID, ticket)
		return errors.New("ticket has expired")
	}

	if amountOut < ticket.MinAmountOut {
		return errors.New("insufficient output amount")
	}

	if ticket.AssetOut.Type == AssetTypeCoin {
		sent := std.GetOrigSend()
		if len(sent) != 1 || sent[0].Denom != ticket.AssetOut.Denom || uint64(sent[0].Amount) != amountOut {
			return errors.New("sent coins don't match fulfillment parameters")
		}
		
		banker := std.GetBanker(std.BankerTypeRealmSend)
		banker.SendCoins(std.CurrentRealm().Addr(), ticket.Creator, sent)

		if ticket.AssetIn.Type == AssetTypeCoin {
			banker.SendCoins(
				std.CurrentRealm().Addr(),
				caller,
				std.Coins{{ticket.AssetIn.Denom, int64(ticket.AmountIn)}},
			)
		} else {
			tokenIn := tokenhub.GetToken(ticket.AssetIn.Token)
			tellerIn := tokenIn.RealmTeller()
			if err := tellerIn.Transfer(caller, ticket.AmountIn); err != nil {
				return errors.New("failed to transfer input token: " + err.Error())
			}
		}
	} else {
		tokenOut := tokenhub.GetToken(ticket.AssetOut.Token)
		if tokenOut == nil {
			return errors.New("token not found: " + ticket.AssetOut.Token)
		}

		tellerOut := tokenOut.RealmTeller()
		if err := tellerOut.TransferFrom(caller, ticket.Creator, amountOut); err != nil {
			return errors.New("failed to transfer output token: " + err.Error())
		}

		if ticket.AssetIn.Type == AssetTypeCoin {
			banker := std.GetBanker(std.BankerTypeRealmSend)
			banker.SendCoins(
				std.CurrentRealm().Addr(),
				caller,
				std.Coins{{ticket.AssetIn.Denom, int64(ticket.AmountIn)}},
			)
		} else {
			tokenIn := tokenhub.GetToken(ticket.AssetIn.Token)
			tellerIn := tokenIn.RealmTeller()
			if err := tellerIn.Transfer(caller, ticket.AmountIn); err != nil {
				return errors.New("failed to transfer input token: " + err.Error())
			}
		}
	}

	ticket.Status = "fulfilled"
	ticketRegistry.tickets.Set(ticketID, ticket)
	return nil
}

// CancelTicket allows the creator to cancel their ticket and withdraw the tokens/coins before the ticket is expired.
func CancelTicket(ticketID string) error {
	caller := std.PrevRealm().Addr()
	
	ticketInterface, exists := ticketRegistry.tickets.Get(ticketID)
	if !exists {
		return errors.New("ticket not found")
	}
	
	ticket := ticketInterface.(*Ticket)

	if ticket.Creator != caller {
		return errors.New("only ticket creator can cancel")
	}

	if ticket.Status != "open" {
		return errors.New("ticket is not open")
	}

	if ticket.AssetIn.Type == AssetTypeCoin {
		banker := std.GetBanker(std.BankerTypeRealmSend)
		banker.SendCoins(
			std.CurrentRealm().Addr(),
			ticket.Creator,
			std.Coins{{ticket.AssetIn.Denom, int64(ticket.AmountIn)}},
		)
	} else {
		tokenIn := tokenhub.GetToken(ticket.AssetIn.Token)
		tellerIn := tokenIn.RealmTeller()
		if err := tellerIn.Transfer(ticket.Creator, ticket.AmountIn); err != nil {
			return errors.New(ufmt.Sprintf("failed to refund tokens: %v", err))
		}
	}

	ticket.Status = "cancelled"
	ticketRegistry.tickets.Set(ticketID, ticket)
	return nil
}

// GetTicket allows a user to get a ticket by its ID. All tickets are named TICKET-<number>.
func GetTicket(ticketID string) (*Ticket, error) {
	ticketInterface, exists := ticketRegistry.tickets.Get(ticketID)
	if !exists {
		return nil, errors.New("ticket not found")
	}
	
	return ticketInterface.(*Ticket), nil
}

// GetAllTickets returns a paginated list of all tickets.
func GetAllTickets(path string) *pager.Page {
	pager := pager.NewPager(ticketRegistry.tickets, 10, true) 
	return pager.MustGetPageByPath(path)
}

// GetOpenTickets returns a paginated list of open, non-expired tickets.
func GetOpenTickets(path string) *pager.Page {
	openTickets := avl.NewTree()
	
	ticketRegistry.tickets.Iterate("", "", func(key string, value interface{}) bool {
		ticket := value.(*Ticket)
		if ticket.Status == "open" && !time.Now().After(ticket.ExpiresAt) {
			openTickets.Set(key, ticket)
		}
		return false
	})
	
	pager := pager.NewPager(openTickets, 2, true)
	return pager.MustGetPageByPath(path)
}

