import type { Request, Response } from 'express';
import { aiService } from './ai.service.js';

export class AiController {
  async chat(req: Request, res: Response) {
    const body = req.body;
    const data = await aiService.chat({
      message: body.message,
      conversationId: body.conversation_id,
      showSources: body.show_sources
    });
    res.json(data);
  }

  async ragAnalyze(req: Request, res: Response) {
    const body = req.body;
    const data = await aiService.ragAnalyze({
      symptoms: body.symptoms,
      showSources: body.show_sources
    });
    res.json(data);
  }
}

export const aiController = new AiController();
