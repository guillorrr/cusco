import { Injectable, signal } from '@angular/core';
import { ApiService } from './api.service';
import { tap } from 'rxjs';

interface LoginResponse {
  access_token: string;
  user: { id: number; email: string; role: string };
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly TOKEN_KEY = 'cusco_token';
  private readonly USER_ROLE_KEY = 'cusco_user_role';

  isAuthenticated = signal(this.hasToken());
  currentUserRole = signal<string>(this.getStoredRole());

  constructor(private api: ApiService) {}

  login(email: string, password: string) {
    return this.api.post<LoginResponse>('auth/login', { email, password }).pipe(
      tap((res) => {
        localStorage.setItem(this.TOKEN_KEY, res.access_token);
        localStorage.setItem(this.USER_ROLE_KEY, res.user.role);
        this.isAuthenticated.set(true);
        this.currentUserRole.set(res.user.role);
      }),
    );
  }

  logout() {
    localStorage.removeItem(this.TOKEN_KEY);
    localStorage.removeItem(this.USER_ROLE_KEY);
    this.isAuthenticated.set(false);
    this.currentUserRole.set('');
  }

  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }

  private hasToken(): boolean {
    return !!localStorage.getItem(this.TOKEN_KEY);
  }

  private getStoredRole(): string {
    return localStorage.getItem(this.USER_ROLE_KEY) ?? '';
  }
}
