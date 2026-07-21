import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const query = searchParams.get('q');

  if (!query) {
    return NextResponse.json({ error: 'Missing query' }, { status: 400 });
  }

  try {
    const res = await fetch(`https://www.youtube.com/results?search_query=${encodeURIComponent(query)}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      }
    });
    
    const html = await res.text();
    
    // Extract ytInitialData
    const match = html.match(/var ytInitialData = ({.*?});/) || html.match(/ytInitialData\s*=\s*({.*?});/);
    if (!match) {
         console.warn("YouTube scraper regex failed. Falling back to Invidious API search...");
         const fallbackResults = await searchInvidious(query);
         return NextResponse.json(fallbackResults);
    }
    
    const data = JSON.parse(match[1]);
    const contents = data.contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer.contents[0].itemSectionRenderer.contents;
    
    const results = contents
        .filter((item: any) => item.videoRenderer)
        .map((item: any) => {
            const video = item.videoRenderer;
            return {
                id: video.videoId,
                title: video.title.runs[0].text,
                artist: video.ownerText?.runs[0]?.text || "Unknown",
                thumbnail: video.thumbnail.thumbnails[0].url,
                duration: parseDuration(video.lengthText?.simpleText)
            };
        });

    return NextResponse.json(results);
    
  } catch (error) {
    console.error("Scraper and fallback failed", error);
    try {
      // Direct secondary attempt
      const fallbackResults = await searchInvidious(query);
      return NextResponse.json(fallbackResults);
    } catch (finalErr) {
      return NextResponse.json({ error: 'Search failed completely' }, { status: 500 });
    }
  }
}

async function searchInvidious(query: string) {
  const INSTANCES = [
    "https://inv.tux.pizza",
    "https://vid.puffyan.us",
    "https://invidious.projectsegfault.net",
    "https://invidious.drgns.space",
    "https://yt.artemislena.eu"
  ];
  for (const instance of INSTANCES) {
    try {
      const res = await fetch(`${instance}/api/v1/search?q=${encodeURIComponent(query)}&type=video`, {
        signal: AbortSignal.timeout(4000)
      });
      if (res.ok) {
        const data = await res.json();
        return data.map((item: any) => ({
          id: item.videoId,
          title: item.title,
          artist: item.author,
          thumbnail: item.videoThumbnails?.find((t: any) => t.quality === 'medium')?.url || `https://i.ytimg.com/vi/${item.videoId}/mqdefault.jpg`,
          duration: item.lengthSeconds
        }));
      }
    } catch (e) {
      console.warn(`Invidious fallback instance ${instance} failed:`, e);
    }
  }
  throw new Error("All fallback instances failed");
}

function parseDuration(text: string): number {
    if(!text) return 0;
    const parts = text.split(':').map(Number);
    if (parts.length === 2) return parts[0] * 60 + parts[1];
    if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    return 0;
}
