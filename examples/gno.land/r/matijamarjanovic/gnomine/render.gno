package gnomine

import (
	"time"
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/md"
)

var statusEmojis = map[string]string{
	"open":      "🟢 Open",      
	"fulfilled": "✅ Fulfilled", 
	"expired":   "⏰ Expired",  
	"cancelled": "❌ Cancelled", 
}

func Render(path string) string {
	str := md.H1("GnoMine Ticket System")
	str += md.Paragraph("View all open tickets for token swaps.")

	openTickets := GetOpenTickets()
	if len(openTickets) == 0 {
		str += md.Blockquote("No open tickets available.")
		return str
	}

	str += md.H2("Open Tickets")
	
	for _, ticket := range openTickets {
		str += md.H3("Ticket #" + ticket.ID)
		
		details := []string{
			"Creator: " + string(ticket.Creator),
			ufmt.Sprintf("Swap: %d %s → (min) %d %s", ticket.AmountIn, ticket.TokenIn, ticket.MinAmountOut, ticket.TokenOut),
			"Created At: " + ticket.CreatedAt.Format(time.RFC3339),
			"Expires At: " + ticket.ExpiresAt.Format(time.RFC3339),
			"Status: " + statusEmojis[ticket.Status],
		}

		str += md.BulletList(details)
		str += md.HorizontalRule()
	}

	return str
}
