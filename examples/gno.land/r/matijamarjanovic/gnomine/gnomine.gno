package gnomine

import (
	"gno.land/p/demo/avl"
)

var(
    poolRegistry *PoolRegistry
    ticketRegistry *TicketRegistry
)

func init() {
    poolRegistry = &PoolRegistry{
        pools: avl.NewTree(),
    }

    ticketRegistry = &TicketRegistry{
		tickets: avl.NewTree(),
	}
}
