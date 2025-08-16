import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { User } from './entities/user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import * as bcrypt from 'bcryptjs';
import { InvitationCodesService } from '../invitation-codes/invitation-codes.service';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    private invitationCodesService: InvitationCodesService,
  ) {}

  async create(createUserDto: CreateUserDto): Promise<User> {
    const { username, password, invitationCode } = createUserDto;

    // Validate and mark invitation code as used
    if (!invitationCode) {
      throw new BadRequestException('Invitation code is required.');
    }
    const validInvitationCode = await this.invitationCodesService.validateCode(invitationCode);

    const existingUser = await this.usersRepository.findOneBy({ username });
    if (existingUser) {
      throw new BadRequestException('Username already exists.');
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = this.usersRepository.create({
      username,
      passwordHash,
      invitationCode: validInvitationCode.code, // Store the actual code from the validated entity
    });

    const savedUser = await this.usersRepository.save(user);
    await this.invitationCodesService.markCodeAsUsed(validInvitationCode.code, savedUser.id);

    return savedUser;
  }

  async findAll(): Promise<User[]> {
    return this.usersRepository.find();
  }

  async findOne(id: string): Promise<User | null> {
    return this.usersRepository.findOneBy({ id });
  }

  async findOneByUsername(username: string): Promise<User | null> {
    return this.usersRepository.findOneBy({ username });
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<User> {
    const user = await this.usersRepository.findOneBy({ id });
    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    if (updateUserDto.username && updateUserDto.username !== user.username) {
      const existingUser = await this.usersRepository.findOneBy({ username: updateUserDto.username });
      if (existingUser) {
        throw new BadRequestException('Username already exists.');
      }
    }

    if (updateUserDto.password) {
      updateUserDto.password = await bcrypt.hash(updateUserDto.password, 10);
    }

    // Merge the existing user with the new data
    Object.assign(user, updateUserDto);

    return this.usersRepository.save(user);
  }

  async findAllByIds(ids: string[]): Promise<User[]> {
    return this.usersRepository.findBy({ id: In(ids) });
  }

  async remove(id: string): Promise<void> {
    const result = await this.usersRepository.delete(id);
    if (result.affected === 0) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }
  }
}
