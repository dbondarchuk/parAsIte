# ParAsIte - AI for OpenTTD which will use competitors infrastructure

This AI is built based on AdmiralAI.

The main purpose of this AI is to make money using competitors' infrastructure.

## How to use this AI

As stock version of OpenTTD doesn't have any API to work with infrastructure sharing option, you need to use **dbpp** patch pack - [https://github.com/dbondarchuk/OpenTTD-patches](https://github.com/dbondarchuk/OpenTTD-patches)

1. Download AdmiralAI from OpenTTD to make sure that you have all needed libs.
2. Download latest release from this repo and put it into 'ai' folder of your OpenTTD.

## Features

1. Building airplanes, trucks and buses on the competitors infrastucture. Trains will be available later.
2. Planting trees as a gesture of charity.

In order for AI to use trucks, pickup station need to have at least one truck with same cargo. This was made in order not mess up your pickup/drop-off stations for industries that consume and produce cargo at the same time.

You can limit max number of buses per stations (including competitors).
Max limit for airport is calculated based on the number of terminals.
