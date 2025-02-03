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
	str += md.Paragraph("View all open tickets for coin and token swaps.")

	page := GetOpenTickets(path)
	if len(page.Items) == 0 {
		str += md.Blockquote("No open tickets available.")
		return str
	}

	str += md.H2("Open Tickets")
	
	for _, item := range page.Items {
		ticket := item.Value.(*Ticket)
		
		swapType := ""
		if ticket.AssetIn.Type == AssetTypeCoin {
			swapType = ticket.AssetIn.Denom + " → " + ticket.AssetOut.Token
		} else if ticket.AssetOut.Type == AssetTypeCoin {
			swapType = ticket.AssetIn.Token + " → " + ticket.AssetOut.Denom
		} else {
			swapType = ticket.AssetIn.Token + " → " + ticket.AssetOut.Token
		}
		
		str += md.H3("#" + ticket.ID + " (" + swapType + ")")
		
		details := []string{
			"Publisher Offers: " + formatAsset(ticket.AssetIn, ticket.AmountIn),
			"Publisher Wants (min): " + formatAsset(ticket.AssetOut, ticket.MinAmountOut),
			"Created At: " + ticket.CreatedAt.Format(time.RFC3339),
			"Expires In: " + formatDuration(ticket.ExpiresAt.Sub(time.Now())),
			"Status: " + statusEmojis[ticket.Status],
		}

		str += md.BulletList(details)
		str += md.HorizontalRule()
	}

	if page.TotalPages > 1 {
		str += "\n\nPages: " + page.Picker()
	}

	return str
}

func formatAsset(asset Asset, amount uint64) string {
	if asset.Type == AssetTypeCoin {
		return ufmt.Sprintf("**%d** %s", amount, asset.Denom)
	}
	return ufmt.Sprintf("**%d** %s", amount, asset.Token)
}

// Helper function to format duration in a user-friendly way
func formatDuration(d time.Duration) string {
	if d <= 0 {
		return "Expired"
	}
	
	hours := int(d.Hours())
	minutes := int(d.Minutes()) % 60
	
	if hours > 24 {
		days := hours / 24
		hours = hours % 24
		return ufmt.Sprintf("%dd %dh", days, hours)
	}
	
	if hours > 0 {
		return ufmt.Sprintf("%dh %dm", hours, minutes)
	}
	
	return ufmt.Sprintf("%dm", minutes)
}
