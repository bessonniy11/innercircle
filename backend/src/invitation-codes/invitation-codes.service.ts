import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InvitationCode } from '../users/entities/invitation-code.entity';
import { v4 as uuidv4 } from 'uuid';

/**
 * Сервис для управления пригласительными кодами
 * 
 * ВРЕМЕННОЕ УПРОЩЕНИЕ (MVP): 
 * - Используется только один универсальный код 'secret_invite'
 * - Код можно использовать неограниченное количество раз
 * - В будущем будет расширен до множественных одноразовых кодов
 * 
 * @class InvitationCodesService
 * @since 1.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Injectable()
export class InvitationCodesService {
  /**
   * Универсальный пригласительный код для MVP
   * @private
   * @readonly
   * @static
   */
  private static readonly UNIVERSAL_CODE = 'secret_invite';

  /**
   * Конструктор сервиса пригласительных кодов
   * @param invitationCodeRepository - Репозиторий для работы с сущностями пригласительных кодов
   */
  constructor(
    @InjectRepository(InvitationCode)
    private invitationCodeRepository: Repository<InvitationCode>,
  ) {}

  /**
   * Генерирует новый случайный пригласительный код
   * 
   * ПРИМЕЧАНИЕ: В текущей версии MVP не используется, 
   * так как применяется единый код 'secret_invite'
   * 
   * @returns Promise<InvitationCode> - Созданный пригласительный код
   * @throws {Error} Ошибка при сохранении в базу данных
   * 
   * @example
   * ```typescript
   * const newCode = await invitationCodesService.generateCode();
   * console.log(newCode.code); // "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
   * ```
   */
  async generateCode(): Promise<InvitationCode> {
    const code = uuidv4();
    const newCode = this.invitationCodeRepository.create({ code });
    return this.invitationCodeRepository.save(newCode);
  }

  /**
   * Проверяет валидность пригласительного кода
   * 
   * В MVP версии:
   * - Принимает только код 'secret_invite'
   * - Автоматически создает запись в БД если её нет
   * - Не проверяет использование (можно использовать многократно)
   * 
   * @param code - Проверяемый пригласительный код
   * @returns Promise<InvitationCode> - Валидный пригласительный код
   * @throws {NotFoundException} Код не найден (не равен 'secret_invite')
   * @throws {BadRequestException} Код уже использован (для будущих версий)
   * 
   * @example
   * ```typescript
   * try {
   *   const validCode = await invitationCodesService.validateCode('secret_invite');
   *   // Код валиден, можно продолжать регистрацию
   * } catch (error) {
   *   // Неверный код или уже использован
   * }
   * ```
   */
  async validateCode(code: string): Promise<InvitationCode> {
    // MVP: Принимаем только универсальный код
    if (code !== InvitationCodesService.UNIVERSAL_CODE) {
      throw new NotFoundException('Invitation code not found.');
    }

    // Ищем существующую запись универсального кода
    let invitation = await this.invitationCodeRepository.findOneBy({ 
      code: InvitationCodesService.UNIVERSAL_CODE 
    });

    // Если записи нет - создаем её автоматически
    if (!invitation) {
      invitation = await this.ensureUniversalCodeExists();
    }

    // MVP: Не проверяем использование - код можно использовать многократно
    // В будущих версиях здесь будет проверка invitation.isUsed

    return invitation;
  }

  /**
   * Помечает пригласительный код как использованный
   * 
   * В MVP версии:
   * - НЕ помечает код как использованный (можно использовать многократно)
   * - Только логирует использование для статистики
   * 
   * @param code - Использованный пригласительный код
   * @param userId - ID пользователя, который использовал код
   * @returns Promise<InvitationCode> - Обновленная запись кода
   * @throws {NotFoundException} Код не найден
   * 
   * @example
   * ```typescript
   * const usedCode = await invitationCodesService.markCodeAsUsed('secret_invite', 'user-123');
   * // В MVP версии код остается доступным для повторного использования
   * ```
   */
  async markCodeAsUsed(code: string, userId: string): Promise<InvitationCode> {
    const invitation = await this.validateCode(code);
    
    // MVP: НЕ помечаем как использованный, только логируем
    // invitation.isUsed = true; // Закомментировано для MVP
    
    // Обновляем информацию о последнем использовании для статистики
    invitation.usedByUserId = userId;
    invitation.usedAt = new Date();
    
    return this.invitationCodeRepository.save(invitation);
  }

  /**
   * Получает список всех пригласительных кодов
   * 
   * @returns Promise<InvitationCode[]> - Массив всех пригласительных кодов
   * 
   * @example
   * ```typescript
   * const allCodes = await invitationCodesService.findAllCodes();
   * console.log(`Всего кодов: ${allCodes.length}`);
   * ```
   */
  async findAllCodes(): Promise<InvitationCode[]> {
    return this.invitationCodeRepository.find();
  }

  /**
   * Обеспечивает существование универсального кода в базе данных
   * 
   * Создает запись 'secret_invite' если она отсутствует в БД.
   * Используется внутренне для автоматической инициализации.
   * 
   * @private
   * @returns Promise<InvitationCode> - Созданная или найденная запись универсального кода
   * @throws {Error} Ошибка при создании записи в БД
   * 
   * @example
   * ```typescript
   * // Вызывается автоматически при первом использовании validateCode()
   * const universalCode = await this.ensureUniversalCodeExists();
   * ```
   */
  private async ensureUniversalCodeExists(): Promise<InvitationCode> {
    const newCode = this.invitationCodeRepository.create({ 
      code: InvitationCodesService.UNIVERSAL_CODE,
      isUsed: false // В MVP не используется, но сохраняем для совместимости
    });
    return this.invitationCodeRepository.save(newCode);
  }

  /**
   * Получает универсальный пригласительный код
   * 
   * Статический метод для получения значения универсального кода.
   * Полезно для тестирования и внешнего использования.
   * 
   * @static
   * @returns string - Универсальный пригласительный код
   * 
   * @example
   * ```typescript
   * const code = InvitationCodesService.getUniversalCode();
   * console.log(code); // "secret_invite"
   * ```
   */
  static getUniversalCode(): string {
    return InvitationCodesService.UNIVERSAL_CODE;
  }
}
