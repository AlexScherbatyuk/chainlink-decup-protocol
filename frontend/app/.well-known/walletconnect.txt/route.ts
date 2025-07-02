import { NextResponse } from 'next/server'

export async function GET() {
    const content = 'b85f8c54-433b-445b-baf9-ef343aaaa21d=3533f3c43d445e41fa403da42f0d3fde13aa82694657be9569abc0426e68fc0a'

    return new NextResponse(content, {
        status: 200,
        headers: {
            'Content-Type': 'text/plain',
        },
    })
} 