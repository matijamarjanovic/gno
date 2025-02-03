package gnomine

import (
	"errors"
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/tokenhub"
)

type Ticket struct {
	ID            string      
	Creator       std.Address 
	TokenIn       string      
	TokenOut      string      
	AmountIn      uint64      
	MinAmountOut  uint64      
	CreatedAt     time.Time   
	ExpiresAt     time.Time   
	Status        string      
}

type TicketRegistry struct {
	tickets *avl.Tree // ticket ID -> *Ticket
}

var (
	ticketRegistry *TicketRegistry
	ticketCounter  uint64
)

func init() {
	ticketRegistry = &TicketRegistry{
		tickets: avl.NewTree(),
	}
	ticketCounter = 0
}

// CreateTicket creates a new swap ticket. On creation it performs various checks to ensure the ticket is valid.
// It checks if the tokens exist, if the caller has enough balance, and if the ticket is not expired. 
// If all checks pass, the amount to be swapped is transferred to the realm, this way there is no race
// condition with the allowance (since it can also be spent in pools.gno).
// If all checks pass, the ticket is created and added to the registry.
func CreateTicket(tokenIn, tokenOut string, amountIn, minAmountOut uint64, expiryHours int64) (string, error) {
	caller := std.PrevRealm().Addr()

	tokenInInstance := tokenhub.GetToken(tokenIn)
	if tokenInInstance == nil {
		return "", errors.New(ufmt.Sprintf("token %s not found", tokenIn))
	}

	tellerIn := tokenInInstance.RealmTeller()
	if err := tellerIn.TransferFrom(
		caller,      
		std.CurrentRealm().Addr(),    
		amountIn,               
	); err != nil {
		return "", errors.New(ufmt.Sprintf("failed to transfer token %s: %v", tokenIn, err))
	}

	tokenOutInstance := tokenhub.GetToken(tokenOut)
	if tokenOutInstance == nil {
		return "", errors.New(ufmt.Sprintf("token %s not found", tokenOut))
	}

	balance := tokenInInstance.BalanceOf(caller)
	if balance < amountIn {
		return "", errors.New(ufmt.Sprintf("insufficient balance for token %s: have %d, need %d", tokenIn, balance, amountIn))
	}

	allowance := tokenInInstance.Allowance(caller, std.CurrentRealm().Addr())
	if allowance < amountIn {
		return "", errors.New(ufmt.Sprintf("insufficient allowance for token %s: have %d, need %d", tokenIn, allowance, amountIn))
	}

	ticketCounter++
	ticketID := ufmt.Sprintf("TICKET-%d", ticketCounter)
	
	now := time.Now()
	ticket := &Ticket{
		ID:           ticketID,
		Creator:      caller,
		TokenIn:      tokenIn, // to swap
		TokenOut:     tokenOut, // to receive
		AmountIn:     amountIn,
		MinAmountOut: minAmountOut,
		CreatedAt:    now,
		ExpiresAt:    now.Add(time.Duration(expiryHours) * time.Hour),
		Status:       "open",
	}

	ticketRegistry.tickets.Set(ticketID, ticket)

	return ticketID, nil
}

// FulfillTicket allows a user to fulfill an open ticket.
// It checks if the ticket is open, if it has not expired, and if the amount out meets the minimum required.
// If all checks pass, the ticket is fulfilled and the tokens are transferred.
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
		return errors.New(ufmt.Sprintf("insufficient output amount: minimum %d, provided %d", ticket.MinAmountOut, amountOut))
	}

	tokenIn := tokenhub.GetToken(ticket.TokenIn)
	tokenOut := tokenhub.GetToken(ticket.TokenOut)

	balance := tokenOut.BalanceOf(caller)
	if balance < amountOut {
		return errors.New(ufmt.Sprintf("insufficient balance for token %s: have %d, need %d", ticket.TokenOut, balance, amountOut))
	}

	tellerIn := tokenIn.RealmTeller()
	if err := tellerIn.Transfer(caller, ticket.AmountIn); err != nil {
		return errors.New(ufmt.Sprintf("failed to transfer input token: %v", err))
	}

	tellerOut := tokenOut.RealmTeller()
	if err := tellerOut.TransferFrom(caller, ticket.Creator, amountOut); err != nil {
		return errors.New(ufmt.Sprintf("failed to transfer output token: %v", err))
	}

	ticket.Status = "fulfilled"
	ticketRegistry.tickets.Set(ticketID, ticket)

	return nil
}

// CancelTicket allows the creator to cancel their ticket and withdraw the tokens before the ticket is expired.
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

	tokenIn := tokenhub.GetToken(ticket.TokenIn)
	tellerIn := tokenIn.RealmTeller()
	if err := tellerIn.Transfer(ticket.Creator, ticket.AmountIn); err != nil {
		return errors.New(ufmt.Sprintf("failed to refund tokens: %v", err))
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

// GetOpenTickets returns all open tickets that have not expired.
func GetOpenTickets() []*Ticket {
	var openTickets []*Ticket
	
	ticketRegistry.tickets.Iterate("", "", func(key string, value interface{}) bool {
		ticket := value.(*Ticket)
		if ticket.Status == "open" && time.Now().After(ticket.ExpiresAt) {
			openTickets = append(openTickets, ticket)
		}
		return false
	})
	
	return openTickets
} 
