import type { Request, Response } from 'express';
import { HttpError } from '../../common/errors/http-error.js';
import { chatService } from './chat.service.js';
import {
  listConversationsQuerySchema,
  listMessagesQuerySchema
} from './chat.schemas.js';

export class ChatController {
  async listConversations(req: Request, res: Response) {
    const query = listConversationsQuerySchema.safeParse(req.query);
    if (!query.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Parametres invalides', query.error.flatten());
    }
    const conversations = await chatService.listConversations(req.user!, query.data.status);
    res.json({ conversations });
  }

  async createConversation(req: Request, res: Response) {
    const conversation = await chatService.createConversation(req.user!, req.body);
    res.status(201).json({ conversation });
  }

  async getConversation(req: Request, res: Response) {
    const conversation = await chatService.getConversation(req.user!, String(req.params.id));
    res.json({ conversation });
  }

  async listMessages(req: Request, res: Response) {
    const query = listMessagesQuerySchema.safeParse(req.query);
    if (!query.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Parametres invalides', query.error.flatten());
    }
    const messages = await chatService.listMessages(req.user!, String(req.params.id), query.data);
    res.json({ messages });
  }

  async sendMessage(req: Request, res: Response) {
    const result = await chatService.sendMessage(req.user!, String(req.params.id), req.body);
    res.status(201).json(result);
  }

  async retryMessage(req: Request, res: Response) {
    const result = await chatService.retryMessage(
      req.user!,
      String(req.params.id),
      String(req.params.messageId)
    );
    res.json(result);
  }

  async updateConversation(req: Request, res: Response) {
    const conversation = await chatService.updateConversation(
      req.user!,
      String(req.params.id),
      req.body
    );
    res.json({ conversation });
  }

  async markRead(req: Request, res: Response) {
    const result = await chatService.markRead(req.user!, String(req.params.id));
    res.json(result);
  }
}

export const chatController = new ChatController();
