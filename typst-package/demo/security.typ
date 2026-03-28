#import "../lib.typ": *
#set page(width: auto, height: auto, margin: 1pt)

#let code = ````
bank:   {
  style.fill: white
  Corporate:   {
    style.fill: white
    app14506: Data Source\ntco:      100,000\nowner: Lakshmi  {
      style:  {
        fill: '#fce7c6'
      }
    }
  }
  Equities:   {
    app14491: Risk Global\ntco:      600,000\nowner: Wendy  {
      style:  {
        fill: '#f6c889'
      }
    }
    app14492: Credit guard\ntco:      100,000\nowner: Lakshmi  {
      style:  {
        fill: '#fce7c6'
      }
    }
    app14520: Seven heaven\ntco:      100,000\nowner: Tomos  {
      style:  {
        fill: '#fce7c6'
      }
    }
    app14522: Apac Ace\ntco:      400,000\nowner: Wendy  {
      style:  {
        fill: '#f9d8a7'
      }
    }
    app14527: Risk Global\ntco:      900,000\nowner: Tomos  {
      style:  {
        fill: '#f4b76c'
      }
    }
  }
  Securities:   {
    style.fill: white
    app14517: Zone out\ntco:      500,000\nowner: Wendy  {
      style:  {
        fill: '#f6c889'
      }
    }
  }
  Finance:   {
    style.fill: white
    app14488: Credit guard\ntco:      700,000\nowner: India  {
      style:  {
        fill: '#f6c889'
      }
    }
    app14502: Ark Crypto\ntco:    1,500,000\nowner: Wendy  {
      style:  {
        fill: '#ed800c'
      }
    }
    app14510: Data Solar\ntco:    1,200,000\nowner: Deepak  {
      style:  {
        fill: '#f1a64f'
      }
    }
  }
  Risk:   {
    style.fill: white
    app14490: Seven heaven\ntco:            0\nowner: Joesph  {
      style:  {
        fill: '#fce7c6'
      }
    }
    app14507: Crypto Bot\ntco:    1,100,000\nowner: Wendy  {
      style:  {
        fill: '#f1a64f'
      }
    }
  }
  Funds:   {
    style.fill: white
    app14497: Risk Global\ntco:      500,000\nowner: Joesph  {
      style:  {
        fill: '#f6c889'
      }
    }
  }
  Fixed Income:   {
    style.fill: white
    app14523: ARC3\ntco:      600,000\nowner: Wendy  {
      style:  {
        fill: '#f6c889'
      }
    }
    app14500: Acmaze\ntco:      100,000\nowner: Tomos  {
      style:  {
        fill: '#fce7c6'
      }
    }
  }
}
bank.Risk.app14490 -> bank.Equities.app14527: client master
bank.Equities.app14491 -> bank.Equities.app14527: greeks  {
  style:  {
    stroke-dash: 5
    animated: true
    stroke: red
  }
}
bank.Funds.app14497 -> bank.Equities.app14520: allocations  {
  style:  {
    stroke-dash: 5
    animated: true
    stroke: brown
  }
}
bank.Equities.app14527 -> bank.Corporate.app14506: trades  {
  style:  {
    stroke-dash: 5
    animated: false
    stroke: blue
  }
}
bank.Fixed Income.app14523 -> bank.Equities.app14491: orders  {
  style:  {
    stroke-dash: 10
    animated: false
    stroke: green
  }
}
bank.Finance.app14488 -> bank.Equities.app14527: greeks  {
  style:  {
    stroke-dash: 5
    animated: true
    stroke: red
  }
}
bank.Equities.app14527 -> bank.Equities.app14522: orders  {
  style:  {
    stroke-dash: 10
    animated: false
    stroke: green
  }
}
bank.Equities.app14522 -> bank.Finance.app14510: orders  {
  style:  {
    stroke-dash: 10
    animated: false
    stroke: green
  }
}
bank.Equities.app14527 -> bank.Finance.app14502: greeks  {
  style:  {
    stroke-dash: 5
    animated: true
    stroke: red
  }
}
bank.Equities.app14527 -> bank.Risk.app14507: allocations  {
  style:  {
    stroke-dash: 5
    animated: true
    stroke: brown
  }
}
bank.Securities.app14517 -> bank.Equities.app14492: trades  {
  style:  {
    stroke-dash: 5
    animated: false
    stroke: blue
  }
}
bank.Equities.app14522 -> bank.Fixed Income.app14500: security reference
````.text

#render(code, engine: "darge")
